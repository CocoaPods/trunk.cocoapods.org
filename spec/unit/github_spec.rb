require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/github'

module Pod::TrunkApp
  class GitHub
    public :url_for
  end

  describe "GitHub" do
    before do
      @auth = { :username => 'alloy', :password => 'secret' }
      @github = GitHub.new('CocoaPods/Specs', 'master', @auth)
      REST.stubs(:get).with(@github.url_for('git/refs/heads/master'), GitHub::HEADERS, @auth).returns(fixture_response('fetch_latest_commit_sha'))
      REST.stubs(:get).with(@github.url_for("git/commits/#{fixture_base_commit_sha}"), GitHub::HEADERS, @auth).returns(fixture_response('fetch_base_tree_sha'))
    end

    it "returns a URL for a given API path" do
      @github.url_for('git/refs/heads/master').should == 'https://api.github.com/repos/CocoaPods/Specs/git/refs/heads/master'
    end

    it "returns the SHA of the latest commit on the `master` branch" do
      @github.fetch_latest_commit_sha.should == fixture_base_commit_sha
    end

    it "returns the SHA of the tree of the latest commit and caches it" do
      @github.fetch_base_tree_sha(fixture_base_commit_sha).should == fixture_base_tree_sha
    end

    before do
      body = {
        :base_tree => fixture_base_tree_sha,
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
      @github.create_new_tree(fixture_base_tree_sha, DESTINATION_PATH, fixture_read('AFNetworking.podspec')).should == fixture_new_tree_sha
    end

    before do
      body = {
        :parents => [fixture_base_commit_sha],
        :tree    => fixture_new_tree_sha,
        :message => MESSAGE,
        :author => {
          :name => 'Eloy Durán',
          :email => 'eloy@example.com',
        },
        :committer => {
          :name => 'alloy',
          :email => 'bot@example.com',
        }
      }.to_json
      REST.stubs(:post).with(@github.url_for('git/commits'), body, GitHub::HEADERS, @auth).returns(fixture_response('create_new_commit'))
    end

    it "creates a new commit object for the new tree object" do
      @github.create_new_commit(fixture_new_tree_sha, fixture_base_commit_sha, '[Add] AFNetworking 1.2.0', 'Eloy Durán', 'eloy@example.com').should == fixture_new_commit_sha
    end

    before do
      body = { :sha => fixture_new_commit_sha }.to_json
      REST.stubs(:patch).with(@github.url_for('git/refs/heads/master'), body, GitHub::HEADERS, @auth).returns(fixture_response('add_commit_to_branch'))
    end

    it "adds a commit to the master branch" do
      @github.add_commit_to_branch(fixture_new_commit_sha, 'master').should == fixture_add_commit_to_branch
    end
  end
end
