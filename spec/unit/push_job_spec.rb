require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/push_job'

module Pod::TrunkApp
  describe PushJob do
    describe 'in general' do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = @pod.add_version(:name => '1.2.0')
        @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
        @job = PushJob.new(@version, @owner, fixture_read('GitHub/KFData.podspec.json'), 'Add')
      end

      before do
        @github = @job.class.github
      end

      it 'configures the GitHub client' do
        @github.basic_auth.should == { :username => 'secret', :password => 'x-oauth-basic' }
      end

      it 'creates log messages before anything else and gets persisted regardless of further errors' do
        @github.stubs(:create_new_commit).raises 'oh noes!'
        should.raise do
          @job.push!
        end
        @version.reload
        @version.log_messages.first.owner.should == @owner
        @version.log_messages.first.message.should.match(/initiated/)
        @version.log_messages.first.data.should == @job.specification_data
        @version.log_messages.last.message.should.match(/failed with error: oh noes!\./)
      end

      extend SpecHelpers::CommitResponse

      it 'creates a new commit in the spec repo and returns its sha' do
        response = response(201, { :commit => { :sha => fixture_new_commit_sha } }.to_json)
        @github.stubs(:create_new_commit).with(@version.destination_path,
                                               @job.specification_data,
                                               MESSAGE,
                                               'Appie',
                                               'appie@example.com').returns(response)

        @job.push!.commit_sha.should == fixture_new_commit_sha
        @version.reload
        @version.log_messages[-2].message.should.match(/initiated/)
        @version.log_messages.last.message.should.match(/has been pushed/)
      end

      describe 'when creating a commit in the spec repo fails' do
        extend SpecHelpers::CommitResponse

        it 'returns `nil`' do
          @github.stubs(:create_new_commit).returns(response(422))
          @job.push!.should.not.be.success
        end

        it 'logs an error on our side in case the response has a 4xx status' do
          @github.stubs(:create_new_commit).returns(response(422, 'DATA'))
          @job.push!.should.be.failed_on_our_side
          log = @version.reload.log_messages.last
          log.level.should == :error
          log.message.should.match /failed with HTTP error `422' on our side/
          log.data.should == 'DATA'
        end

        it 'logs a warning on their (GitHub) side in case the response has a 5xx status' do
          @github.stubs(:create_new_commit).returns(response(503, 'DATA'))
          @job.push!.should.be.failed_on_their_side
          log = @version.reload.log_messages.last
          log.level.should == :warning
          log.message.should.match /failed with HTTP error `503' on GitHub’s side/
          log.data.should == 'DATA'
        end

        it 'logs a warning on neither side in case a timeout occurs' do
          @github.stubs(:create_new_commit).returns(response { raise Timeout::Error, 'execution expired' })
          @job.push!.should.be.failed_due_to_timeout
          log = @version.reload.log_messages.last
          log.level.should == :warning
          log.message.should.match /failed due to timeout/
          log.data.should == '[Timeout::Error] execution expired'
        end

        it 'logs the duration' do
          @github.stubs(:create_new_commit).returns(response(422))
          lambda do
            @job.push!
          end.should.change { LogMessage.count }
          @version.reload
          log = @version.log_messages.last
          log.level.should == :error
          log.message.should.match(/\d\ss\).\z/)
        end
      end
    end
  end
end
