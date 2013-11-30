require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/submission_job'

module Pod::TrunkApp
  class SubmissionJob
    public :perform_work
  end

  describe "SubmissionJob" do
    before do
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(:pod => @pod, :name => '1.2.0', :url => 'http://host/pods/AFNetworking/versions/1.2.0')
      @job = @version.add_submission_job(:specification_data => fixture_read('AFNetworking.podspec'), :owner => @owner)
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

    it "takes a job from the queue and performs the next task" do
      SubmissionJob.any_instance.expects(:perform_next_task!)
      SubmissionJob.perform_task!.should == true
    end

    it "returns that there was no work to perform if there are no jobs that need work done" do
      @job.update(:needs_to_perform_work => false)
      SubmissionJob.any_instance.expects(:perform_next_task!).never
      SubmissionJob.perform_task!.should == false
    end

    it "considers a build failed once the retry count is reached" do
      @job.update(:attempts => SubmissionJob::RETRY_COUNT)
      @job.reload.should.be.failed
      @job.should.not.needs_to_perform_work
    end

    describe "concerning submission progress state" do
      before do
        @github = @job.send(:github)
        @github.stubs(:fetch_latest_commit_sha).returns(fixture_base_commit_sha)
        @github.stubs(:fetch_base_tree_sha).returns(fixture_base_tree_sha)
        @github.stubs(:create_new_tree).with(fixture_base_tree_sha, DESTINATION_PATH, fixture_read('AFNetworking.podspec')).returns(fixture_new_tree_sha)
        @github.stubs(:create_new_commit).with(fixture_new_tree_sha, fixture_base_commit_sha, MESSAGE, 'Appie', 'appie@example.com').returns(fixture_new_commit_sha)
        @github.stubs(:add_commit_to_branch).with(fixture_new_commit_sha, 'master').returns(fixture_add_commit_to_branch)
      end

      it "configures the GitHub client" do
        @github.basic_auth.should == { :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic' }
      end

      it "initializes with a new state" do
        @job.should.needs_to_perform_work
        @job.should.be.in_progress
      end

      it "creates log messages before anything else and gets persisted regardless of further errors" do
        @job.perform_work 'A failing task' do
          @job.update(:base_commit_sha => fixture_base_commit_sha)
          raise "oh noes!"
        end
        @job.log_messages.last(2).map(&:message).should == ["A failing task", "Error: oh noes!"]
        @job.reload.base_commit_sha.should == nil

        @job.perform_work 'A succeeding task' do
          @job.update(:base_commit_sha => fixture_base_commit_sha)
        end
        @job.log_messages.last.message.should == "A succeeding task"
        @job.reload.base_commit_sha.should == fixture_base_commit_sha
      end

      it "bumps the attempt count as long as the threshold isn't reached" do
        SubmissionJob::RETRY_COUNT.times do |i|
          @job.perform_work "Try #{i+1}" do
            raise "oh noes!"
          end
        end
        @job.should.be.failed
        @job.should.not.needs_to_perform_work
      end

      it "fetches the SHA of the commit this PR will be based on" do
        @job.perform_next_task!
        @job.base_commit_sha.should == fixture_base_commit_sha
        @job.tasks_completed.should == 1
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Fetching latest commit SHA."
      end

      before do
        @job.update(:base_commit_sha => fixture_base_commit_sha)
      end

      it "fetches the SHA of the tree of the base commit" do
        @job.perform_next_task!
        @job.base_tree_sha.should == fixture_base_tree_sha
        @job.tasks_completed.should == 2
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Fetching tree SHA of commit #{fixture_base_commit_sha}."
      end

      before do
        @job.update(:base_tree_sha => fixture_base_tree_sha)
      end

      it "creates a new tree" do
        @job.perform_next_task!
        @job.new_tree_sha.should == fixture_new_tree_sha
        @job.tasks_completed.should == 3
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Creating new tree based on tree #{fixture_base_tree_sha}."
      end

      before do
        @job.update(:new_tree_sha => fixture_new_tree_sha)
      end

      it "creates a new commit" do
        @job.perform_next_task!
        @job.new_commit_sha.should == fixture_new_commit_sha
        @job.tasks_completed.should == 4
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Creating new commit with tree #{fixture_new_tree_sha}."
      end

      before do
        @job.update(:new_commit_sha => fixture_new_commit_sha)
      end

      it "adds a commit to the master branch" do
        @job.stubs(:after_update)
        @job.perform_next_task!
        @job.new_commit_url.should == fixture_add_commit_to_branch
        @job.tasks_completed.should == 5
        @job.should.not.needs_to_perform_work
        @job.log_messages.last.message.should == "Adding commit to master branch #{fixture_new_commit_sha}."
      end

      it "publishes the pod version once the pull-request has been merged" do
        @job.perform_next_task!
        @version.should.be.published
        @version.published_by_submission_job.should == @job
        @version.commit_sha.should == fixture_new_commit_sha
        @job.log_messages.last.message.should == "Published."
      end
    end

    describe "when the submission flow fails" do
    end
  end
end
