require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  class GitHub
    public :url_for
  end

  describe "GitHub" do
    def fixture_response(name)
      YAML.unsafe_load(fixture_read("GitHub/#{name}.yaml"))
    end

    before do
      @auth = { :username => 'alloy', :password => 'secret' }
      @github = GitHub.new('CocoaPods/Specs', 'master', @auth)
      REST.stubs(:get).with(@github.url_for('git/refs/heads/master'), GitHub::HEADERS, @auth).returns(fixture_response('sha_latest_commit'))
      REST.stubs(:get).with(@github.url_for('git/commits/632671a3f28771a3631119354731dba03963a276'), GitHub::HEADERS, @auth).returns(fixture_response('sha_base_tree'))
    end

    it "returns a URL for a given API path" do
      @github.url_for('git/refs/heads/master').should == 'https://api.github.com/repos/CocoaPods/Specs/git/refs/heads/master'
    end

    it "returns the SHA of the latest commit on the `master` branch" do
      @github.fetch_latest_commit_sha.should == BASE_COMMIT_SHA
    end

    it "returns the SHA of the tree of the latest commit and caches it" do
      @github.fetch_base_tree_sha(BASE_COMMIT_SHA).should == BASE_TREE_SHA
    end

    before do
      body = {
        :base_tree => BASE_TREE_SHA,
        :tree => [{
          :encoding => 'utf-8',
          :mode     => '100644',
          :path     => DESTINATION_PATH,
          :content  => fixture_read('AFNetworking.podspec')
        }]
      }.to_json
      REST.stubs(:post).with(@github.url_for('git/trees'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_new_tree'))
    end

    it "creates a new tree object, which represents the contents, and returns its SHA" do
      @github.create_new_tree(BASE_TREE_SHA, DESTINATION_PATH, fixture_read('AFNetworking.podspec')).should == NEW_TREE_SHA
    end

    before do
      body = {
        :parents => [BASE_COMMIT_SHA],
        :tree    => NEW_TREE_SHA,
        :message => MESSAGE
      }.to_json
      REST.stubs(:post).with(@github.url_for('git/commits'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_new_commit'))
    end

    it "creates a new commit object for the new tree object" do
      @github.create_new_commit(NEW_TREE_SHA, BASE_COMMIT_SHA, '[Add] AFNetworking 1.2.0').should == NEW_COMMIT_SHA
    end

    before do
      body = {
        :ref => 'refs/heads/AFNetworking-1.2.0-job-42',
        :sha => NEW_COMMIT_SHA
      }.to_json
      REST.stubs(:post).with(@github.url_for('git/refs'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_new_branch'))
    end

    it "creates a new branch object with a new commit object" do
      @github.create_new_branch(NEW_BRANCH_NAME % '42', NEW_COMMIT_SHA).should == NEW_BRANCH_REF % '42'
    end

    before do
      body = {
        :title => '[Add] AFNetworking 1.2.0',
        :body  => 'Specification for AFNetworking 1.2.0',
        :head  => NEW_BRANCH_REF % '42',
        :base  => 'refs/heads/master'
      }.to_json
      REST.stubs(:post).with(@github.url_for('pulls'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_pull-request'))
    end

    it "creates a new pull-request for a branch and returns the pull/issue number" do
      @github.create_new_pull_request('[Add] AFNetworking 1.2.0', 'Specification for AFNetworking 1.2.0', NEW_BRANCH_REF % '42').should == NEW_PR_NUMBER
    end

    before do
      REST.stubs(:put).with(@github.url_for("pulls/#{NEW_PR_NUMBER}/merge"), '{}', GitHub::HEADERS, @auth).returns(fixture_response('merge_pull-request'))
    end

    it "merges a pull-request for a branch and returns the merge commit SHA" do
      @github.merge_pull_request(NEW_PR_NUMBER).should == MERGE_COMMIT_SHA
    end
  end
end
