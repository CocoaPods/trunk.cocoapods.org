require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/push_job'

module Pod::TrunkApp
  describe PushJob do
    describe "in general" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = @pod.add_version(:name => '1.2.0')
        @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
        @job = PushJob.new(@version, @owner, fixture_read('GitHub/KFData.podspec.json'))
      end

      before do
        @github = @job.class.github
      end

      it "configures the GitHub client" do
        @github.basic_auth.should == { :username => 'secret', :password => 'x-oauth-basic' }
      end

      it "creates log messages before anything else and gets persisted regardless of further errors" do
        @github.stubs(:create_new_commit).raises 'oh noes!'
        should.raise do
          @job.push!
        end
        @version.reload
        @version.log_messages.first.owner.should == @owner
        @version.log_messages.first.message.match(%r{initiated.}).should.not == nil
        @version.log_messages.first.data.should == @job.specification_data
        @version.log_messages.last.message.match(%r{failed with error: oh noes!\.}).should.not == nil
      end

      it "creates a new commit in the spec repo and returns its sha" do
        response = REST::Response.new(201, {}, { :commit => { :sha => fixture_new_commit_sha } }.to_json)
        response.extend(GitHub::CommitResponseExt)
        @github.stubs(:create_new_commit).with(@version.destination_path,
                                               @job.specification_data,
                                               MESSAGE,
                                               'Appie',
                                               'appie@example.com').returns(response)

        @job.push!.should == fixture_new_commit_sha
        @version.reload
        @version.log_messages[-2].message.match(%r{has been pushed}).should.not == nil
        @version.log_messages.last.message.match(%r{seconds}).should.not == nil
      end

      describe "when creating a commit in the spec repo fails" do
        it "returns `nil`" do
          @github.stubs(:create_new_commit).returns(REST::Response.new(422))
          @job.push!.should == nil
        end

        it "logs an error on our side in case the response has a 4xx status" do
          @github.stubs(:create_new_commit).returns(REST::Response.new(422, {}, 'DATA'))
          @job.push!
          log = @version.reload.log_messages[-2]
          log.level.should == :error
          log.message.should.end_with "failed with HTTP error `422' on our side."
          log.data.should == 'DATA'
        end

        it "logs a warning on their (GitHub) side in case the response has a 5xx status" do
          @github.stubs(:create_new_commit).returns(REST::Response.new(503, {}, 'DATA'))
          @job.push!
          log = @version.reload.log_messages[-2]
          log.level.should == :warning
          log.message.should.end_with "failed with HTTP error `503' on GitHub’s side."
          log.data.should == 'DATA'
        end

        it "raises in case of a complete unexpected response" do
          @github.stubs(:create_new_commit).returns(REST::Response.new(100))
          should.raise do
            @job.push!
          end
        end
        
        it "logs the duration" do
          @github.stubs(:create_new_commit).returns(REST::Response.new(422))
          lambda {
            @job.push!
          }.should.change { LogMessage.count }
          @version.reload
          log = @version.log_messages.last
          log.level.should == :info
          log.message.match(%r{Push for `AFNetworking 1.2.0' with temporary ID `\d{14}' took 0\.\d{6} seconds\.})
            .should.not == nil
        end
      end
    end
  end
end
