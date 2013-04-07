require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/github'

module Pod::PushApp
  describe "GitHub" do
    def fixture_response(name)
      YAML.load(fixture_read("GitHub/#{name}.yaml"))
    end

    before do
      @github = GitHub.new('AFNetworking/1.2.0/AFNetworking.podspec', fixture_read('AFNetworking.podspec'))
      REST.stubs(:get).with(@github.url_for('git/refs/heads/master'), GitHub::HEADERS, GitHub::BASIC_AUTH).returns(fixture_response('sha_latest_commit'))
      REST.stubs(:get).with(@github.url_for('git/commits/632671a3f28771a3631119354731dba03963a276'), GitHub::HEADERS, GitHub::BASIC_AUTH).returns(fixture_response('sha_base_tree'))
    end

    it "returns a URL for a given API path" do
      @github.url_for('git/refs/heads/master').should == 'https://api.github.com/repos/CocoaPods/Specs/git/refs/heads/master'
    end

    it "returns the SHA of the latest commit on the `master` branch" do
      @github.sha_latest_commit.should == '632671a3f28771a3631119354731dba03963a276'
    end

    it "returns the SHA of the tree of the latest commit" do
      @github.sha_base_tree.should == 'f93e3a1a1525fb5b91020da86e44810c87a2d7bc'
    end

    it "creates a new tree entry, which represents the contents, and returns its SHA" do
      expected_body = {
        :base_tree => 'f93e3a1a1525fb5b91020da86e44810c87a2d7bc',
        :tree => [{
          :encoding => 'utf-8',
          :mode     => '100644',
          :path     => 'AFNetworking/1.2.0/AFNetworking.podspec',
          :content  => fixture_read('AFNetworking.podspec')
        }]
      }.to_json
      REST.expects(:post).with(@github.url_for('git/trees'), expected_body, GitHub::HEADERS, GitHub::BASIC_AUTH).returns(fixture_response('create_new_tree'))
      @github.create_new_tree.should == '18f8a32cdf45f0f627749e2be25229f5026f93ac'
    end
  end
end
