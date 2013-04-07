require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/github'

module Pod::PushApp
  describe "GitHub" do
    def fixture_response(name)
      YAML.load(fixture_read("GitHub/#{name}.yaml"))
    end

    before do
      @github = GitHub.new('AFNetworking/1.2.0/AFNetworking.podspec', fixture_read('AFNetworking.podspec'))
    end

    it "returns a URL for a given API path" do
      @github.url_for('git/refs/heads/master').should == 'https://api.github.com/repos/CocoaPods/Specs/git/refs/heads/master'
    end

    it "returns the SHA of the latest commit on the `master` branch" do
      REST.expects(:get).with(@github.url_for('git/refs/heads/master'), GitHub::HEADERS, GitHub::BASIC_AUTH).returns(fixture_response('sha_latest_commit'))
      @github.sha_latest_commit.should == '632671a3f28771a3631119354731dba03963a276'
    end
  end
end
