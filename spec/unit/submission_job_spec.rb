require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "SubmissionJob" do
    describe "concerning submission progress state" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0', :url => 'http://host/pods/AFNetworking/versions/1.2.0')
        @job = @version.add_submission_job(:specification_data => fixture_read('AFNetworking.podspec'))

        github = @job.send(:github)
        github.stubs(:fetch_latest_commit_sha).returns(BASE_COMMIT_SHA)
        github.stubs(:fetch_base_tree_sha).returns(BASE_TREE_SHA)
        github.stubs(:create_new_tree).with(BASE_TREE_SHA, DESTINATION_PATH, fixture_read('AFNetworking.podspec')).returns(NEW_TREE_SHA)
        github.stubs(:create_new_commit).with(NEW_TREE_SHA, BASE_COMMIT_SHA, MESSAGE).returns(NEW_COMMIT_SHA)
        github.stubs(:create_new_branch).with(NEW_BRANCH_NAME, NEW_COMMIT_SHA).returns(NEW_BRANCH_REF)
        github.stubs(:create_new_pull_request).with(MESSAGE, @version.url, NEW_BRANCH_REF).returns(NEW_PR_NUMBER)
      end

      it "initializes with a new state" do
        @job.state.should == 'submitted'
        @job.should.be.submitted
      end

      it "fetches the SHA of the commit this PR will be based on" do
        @job.perform_next_pull_request_task!
        #@job.state.should == 'fetched_base_commit_sha'
        @job.base_commit_sha.should == BASE_COMMIT_SHA
        # TODO test that this is being done at the start of the method?
        @job.log_messages.last.message.should == "Fetching latest commit SHA."
      end

      before do
        @job.update(:base_commit_sha => BASE_COMMIT_SHA)
      end

      it "fetches the SHA of the tree of the base commit" do
        @job.perform_next_pull_request_task!
        @job.base_tree_sha.should == BASE_TREE_SHA
        # TODO test that this is being done at the start of the method?
        @job.log_messages.last.message.should == "Fetching tree SHA of commit #{BASE_COMMIT_SHA}."
      end

      before do
        @job.update(:base_tree_sha => BASE_TREE_SHA)
      end

      it "creates a new tree" do
        @job.perform_next_pull_request_task!
        @job.new_tree_sha.should == NEW_TREE_SHA
        # TODO test that this is being done at the start of the method?
        @job.log_messages.last.message.should == "Creating new tree based on tree #{BASE_TREE_SHA}."
      end

      before do
        @job.update(:new_tree_sha => NEW_TREE_SHA)
      end

      it "creates a new commit" do
        @job.perform_next_pull_request_task!
        @job.new_commit_sha.should == NEW_COMMIT_SHA
        # TODO test that this is being done at the start of the method?
        @job.log_messages.last.message.should == "Creating new commit with tree #{NEW_TREE_SHA}."
      end

      before do
        @job.update(:new_commit_sha => NEW_COMMIT_SHA)
      end

      it "creates a new branch" do
        @job.perform_next_pull_request_task!
        @job.new_branch_ref.should == NEW_BRANCH_REF
        # TODO test that this is being done at the start of the method?
        @job.log_messages.last.message.should == "Creating new branch `#{NEW_BRANCH_NAME}' with commit #{NEW_COMMIT_SHA}."
      end

      before do
        @job.update(:new_branch_ref => NEW_BRANCH_REF)
      end

      it "creates a new pull-request and changes state" do
        @job.perform_next_pull_request_task!
        @job.pull_request_number.should == NEW_PR_NUMBER
        # TODO test that this is being done at the start of the method?
        @job.log_messages.last.message.should == "Creating new pull-request with branch #{NEW_BRANCH_REF}."

        @job.state.should == 'pull-request-submitted'
        @job.should.be.pull_request_submitted
      end

      it "merges a pull-request" do
        # TODO
      end
    end
  end
end

