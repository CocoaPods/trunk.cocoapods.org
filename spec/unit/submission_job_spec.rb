require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/submission_job'

module Pod::TrunkApp
  class SubmissionJob
    public :perform_task
  end

  describe "SubmissionJob" do
    before do
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(:pod => @pod, :name => '1.2.0', :url => 'http://host/pods/AFNetworking/versions/1.2.0')
      @job = @version.add_submission_job(:specification_data => fixture_read('AFNetworking.podspec'))
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

    describe "concerning submission progress state" do
      before do
        github = @job.send(:github)
        github.stubs(:fetch_latest_commit_sha).returns(BASE_COMMIT_SHA)
        github.stubs(:fetch_base_tree_sha).returns(BASE_TREE_SHA)
        github.stubs(:create_new_tree).with(BASE_TREE_SHA, DESTINATION_PATH, fixture_read('AFNetworking.podspec')).returns(NEW_TREE_SHA)
        github.stubs(:create_new_commit).with(NEW_TREE_SHA, BASE_COMMIT_SHA, MESSAGE).returns(NEW_COMMIT_SHA)
        github.stubs(:create_new_branch).with(NEW_BRANCH_NAME % @job.id, NEW_COMMIT_SHA).returns(NEW_BRANCH_REF % @job.id)
        github.stubs(:create_new_pull_request).with(MESSAGE, @version.url, NEW_BRANCH_REF % @job.id).returns(NEW_PR_NUMBER)
        github.stubs(:merge_pull_request).with(NEW_PR_NUMBER).returns(MERGE_COMMIT_SHA)
      end

      it "initializes with a new state" do
        @job.should.needs_to_perform_work
        @job.should.be.in_progress
      end

      it "creates log messages before anything else and gets persisted regardless of further errors" do
        @job.perform_task 'A failing task' do
          @job.update(:pull_request_number => 42)
          raise "oh noes!"
        end
        @job.log_messages.last(2).map(&:message).should == ["A failing task", "Error: oh noes!"]
        @job.reload.pull_request_number.should == nil

        @job.perform_task 'A succeeding task' do
          @job.update(:pull_request_number => 42)
        end
        @job.log_messages.last.message.should == "A succeeding task"
        @job.reload.pull_request_number.should == 42
      end

      it "considers a job failed if the retry threshold is reached" do
        SubmissionJob::RETRY_COUNT.times do |i|
          @job.perform_task "Try #{i+1}" do
            raise "oh noes!"
          end
        end
        @job.should.be.failed
        @job.should.not.needs_to_perform_work
      end

      it "fetches the SHA of the commit this PR will be based on" do
        @job.perform_next_task!
        @job.base_commit_sha.should == BASE_COMMIT_SHA
        @job.tasks_completed.should == 1
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Fetching latest commit SHA."
      end

      before do
        @job.update(:base_commit_sha => BASE_COMMIT_SHA)
      end

      it "fetches the SHA of the tree of the base commit" do
        @job.perform_next_task!
        @job.base_tree_sha.should == BASE_TREE_SHA
        @job.tasks_completed.should == 2
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Fetching tree SHA of commit #{BASE_COMMIT_SHA}."
      end

      before do
        @job.update(:base_tree_sha => BASE_TREE_SHA)
      end

      it "creates a new tree" do
        @job.perform_next_task!
        @job.new_tree_sha.should == NEW_TREE_SHA
        @job.tasks_completed.should == 3
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Creating new tree based on tree #{BASE_TREE_SHA}."
      end

      before do
        @job.update(:new_tree_sha => NEW_TREE_SHA)
      end

      it "creates a new commit" do
        @job.perform_next_task!
        @job.new_commit_sha.should == NEW_COMMIT_SHA
        @job.tasks_completed.should == 4
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Creating new commit with tree #{NEW_TREE_SHA}."
      end

      before do
        @job.update(:new_commit_sha => NEW_COMMIT_SHA)
      end

      it "creates a new branch" do
        @job.perform_next_task!
        @job.new_branch_ref.should == NEW_BRANCH_REF % @job.id
        @job.tasks_completed.should == 5
        @job.should.needs_to_perform_work
        @job.log_messages.last.message.should == "Creating new branch `#{NEW_BRANCH_NAME % @job.id}' with commit #{NEW_COMMIT_SHA}."
      end

      before do
        @job.update(:new_branch_ref => NEW_BRANCH_REF % @job.id)
      end

      it "creates a new pull-request and changes state to no longer needing work (until Travis reports back)" do
        @job.perform_next_task!
        @job.pull_request_number.should == NEW_PR_NUMBER
        @job.tasks_completed.should == 6
        @job.should.not.needs_to_perform_work
        @job.log_messages.last.message.should == "Creating new pull-request with branch #{NEW_BRANCH_REF % @job.id}."
      end

      before do
        @job.update(:pull_request_number => NEW_PR_NUMBER, :needs_to_perform_work => false)
      end

      it "does not allow to perform a next task until travis reports back" do
        should.raise SubmissionJob::TaskError do
          @job.perform_next_task!
        end
      end

      it "changes the state to needing work if travis succeeds to build the pull-request" do
        @job.update(:travis_build_success => true)
        @job.should.needs_to_perform_work
      end

      it "considers the job to have failed if travis reports a build failure" do
        @job.update(:travis_build_success => false)
        @job.should.not.needs_to_perform_work
        @job.should.be.failed
      end

      before do
        @job.update(:travis_build_success => true)
      end

      it "merges a pull-request and changes state to not needing any more work done" do
        @job.perform_next_task!
        @job.merge_commit_sha.should == MERGE_COMMIT_SHA
        @job.tasks_completed.should == 7
        @job.should.not.needs_to_perform_work
        @job.should.be.completed
        @job.log_messages.last.message.should == "Merging pull-request number #{NEW_PR_NUMBER}"
      end

      it "publishes the pod version once the pull-request has been merged" do
        @job.perform_next_task!
        @version.should.be.published
      end
    end
  end
end

