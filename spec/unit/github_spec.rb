require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/github'

module Pod::TrunkApp
  describe "GitHub" do
    before do
      @auth = { :username => 'alloy', :password => 'secret' }
      @github = GitHub.new('CocoaPods/Specs', @auth)
    end

    it "returns a URL for a given API path" do
      @github.url_for('git/refs/heads/master').should == 'https://api.github.com/repos/CocoaPods/Specs/git/refs/heads/master'
    end

    it "creates a new commit" do
      # Capture the args so we can assert on them after the call.
      args = nil
      REST.stubs(:put).with do |url, body, headers, auth|
        args = [url, body, headers, auth]
      end.returns(fixture_response('create_new_commit'))

      @github.create_new_commit(DESTINATION_PATH,
                                fixture_read('AFNetworking.podspec'),
                                '[Add] AFNetworking 1.2.0',
                                'Eloy Durán',
                                'eloy@example.com').should == fixture_new_commit_sha

      url, body, headers, auth = args

      url.should == @github.url_for(File.join('contents', DESTINATION_PATH))
      headers.should == GitHub::HEADERS
      auth.should == @auth

      body = JSON.parse(body)
      Base64.decode64(body['content']).should == fixture_read('AFNetworking.podspec')
      body.delete('content')
      body.should == {
        'message'   => MESSAGE,
        'branch'    => 'master',
        'author'    => { 'name' => 'Eloy Durán', 'email' => 'eloy@example.com' },
        'committer' => { 'name' => 'alloy',      'email' => 'bot@example.com' },
      }
    end
  end
end
