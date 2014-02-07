require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/submission_job'

module Pod::TrunkApp
  class SubmissionJob
    public :perform_work
  end

  describe "SubmissionJob" do
    before do
      @pod = Pod.create(:name => 'AFNetworking')
      @version = @pod.add_version(:name => '1.2.0')
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @job = @version.add_submission_job(:specification_data => fixture_read('AFNetworking.podspec'), :owner => @owner)
    end

    describe "concerning validations" do
      it "needs a pod version" do
        @job.should.not.validate_with(:pod_version_id, nil)
        @job.should.validate_with(:pod_version_id, @version.id)
      end

      it "needs an owner" do
        @job.should.not.validate_with(:owner_id, nil)
        @job.should.validate_with(:owner_id, @owner.id)
      end

      it "needs specification data" do
        @job.should.not.validate_with(:specification_data, nil)
        @job.should.not.validate_with(:specification_data, '')
        @job.should.not.validate_with(:specification_data, ' ')
        @job.should.validate_with(:specification_data, fixture_read('AFNetworking.podspec'))
      end

      it "needs a valid commit sha" do
        @job.should.not.validate_with(:commit_sha, '')
        @job.should.not.validate_with(:commit_sha, '3ca23060')
        @job.should.not.validate_with(:commit_sha, 'g' * 40) # hex only
        @job.should.validate_with(:commit_sha, '3ca23060197547eef92983f15590b5a87270615f')
      end

      describe "at the DB level" do
        it "raises if an empty `pod_version_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @job.pod_version_id = nil
            @job.save(:validate => false)
          end
        end

        it "raises if an empty `owner_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @job.owner_id = nil
            @job.save(:validate => false)
          end
        end

        it "raises if an empty `specification_data' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @job.specification_data = nil
            @job.save(:validate => false)
          end
        end
      end
    end

    describe "in general" do
      before do
        @job.save
      end

      it "returns the duration in seconds relative to now" do
        now = 41.seconds.from_now
        Time.stubs(:now).returns(now)
        @job.duration.should == 42
      end

      it "returns the duration in seconds relative till the latest update once finished" do
        @job.update(:succeeded => false)
        now = 41.seconds.from_now
        Time.stubs(:now).returns(now)
        @job.duration.should == 1
      end

      before do
        @github = @job.class.send(:github)
      end

      it "configures the GitHub client" do
        @github.basic_auth.should == { :username => 'secret', :password => 'x-oauth-basic' }
      end

      it "initializes with a new state" do
        @job.should.be.in_progress
      end

      it "creates log messages before anything else and gets persisted regardless of further errors" do
        result = @job.perform_work 'A failing task' do
          @job.update(:commit_sha => '3ca23060197547eef92983f15590b5a87270615f')
          raise "oh noes!"
        end
        result.should == false
        @job.log_messages.last(2).map(&:message).should == ["A failing task", "Failed with error: oh noes!"]
        @job.reload.commit_sha.should == nil

        result = @job.perform_work 'A succeeding task' do
          @job.update(:commit_sha => '3ca23060197547eef92983f15590b5a87270615f')
        end
        result.should == true
        @job.log_messages.last.message.should == "A succeeding task"
        @job.reload.commit_sha.should == '3ca23060197547eef92983f15590b5a87270615f'
      end

      it "reports it failed" do
        @github.stubs(:create_new_commit).raises
        @job.submit_specification_data!.should == false
        @job.reload.should.be.failed
        @job.should.not.be.completed
      end

      before do
        @github.stubs(:create_new_commit).with(@version.destination_path,
                                               @job.specification_data,
                                               MESSAGE,
                                               'Appie',
                                               'appie@example.com').returns(fixture_new_commit_sha)
      end

      it "creates a new commit" do
        @job.submit_specification_data!.should == true
        @job.reload.commit_sha.should == fixture_new_commit_sha
        @job.reload.should.be.completed
        @job.should.not.be.failed
        @job.log_messages.first.message.should == 'Submitting specification data to GitHub'
      end

      it "publishes the pod version once the commit has been created" do
        @job.submit_specification_data!
        @version.should.be.published
        @version.published_by_submission_job.should == @job
        @version.commit_sha.should == fixture_new_commit_sha
        @job.log_messages.last.message.should == "Published."
      end

      it "adds the submitter as the owner of the pod if the pod has no owners yet" do
        @job.submit_specification_data!
        @pod.reload.owners.should == [@owner]
      end
    end
  end
end
