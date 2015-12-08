require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/github'

module Pod::TrunkApp
  describe 'GitHub' do
    before do
      @auth = { :username => 'alloy', :password => 'secret' }
      @github = GitHub.new('CocoaPods/Specs', @auth)
    end

    it 'returns a URL for a given API path' do
      @github.url_for('git/refs/heads/master').should == 'https://api.github.com/repos/CocoaPods/Specs/git/refs/heads/master'
    end

    it 'configures timeouts' do
      Net::HTTP.last_started_request = nil
      @github.put('/',  :foo => 'bar')
      http_request = Net::HTTP.last_started_request
      http_request.open_timeout.should == 3
      http_request.read_timeout.should == 7
    end

    it 'creates a new commit' do
      # Capture the args so we can assert on them after the call.
      args = nil
      REST::Request.stubs(:perform).with do |method, url, body, headers, auth|
        args = [url.to_s, body, headers, auth]
      end.returns(fixture_response('create_new_commit'))

      response = @github.create_new_commit(DESTINATION_PATH,
                                           fixture_read('AFNetworking.podspec'),
                                           '[Add] AFNetworking 1.2.0',
                                           'Eloy Durán',
                                           'eloy@example.com')
      response.should.be.success
      response.commit_sha.should == fixture_new_commit_sha

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
        'committer' => { 'name' => 'alloy',      'email' => 'bot@example.com' }
      }
    end

    describe 'concerning the response object' do
      extend SpecHelpers::CommitResponse

      it 'returns the commit was a success' do
        response(201).should.be.success
        response(201).should.not.be.failed_on_our_side
        response(201).should.not.be.failed_on_their_side
        response(302).should.be.success
        response(302).should.not.be.failed_on_our_side
        response(302).should.not.be.failed_on_their_side
      end

      it 'returns the commit failed on our side, i.e. our request was incorrect' do
        response(400).should.not.be.success
        response(400).should.be.failed_on_our_side
        response(400).should.not.be.failed_on_their_side
      end

      it 'returns the commit failed on their side, i.e. GitHub ran into an unexpected exception' do
        response(500).should.not.be.success
        response(500).should.not.be.failed_on_our_side
        response(500).should.be.failed_on_their_side
      end

      it 'raises in case of an unexpected status' do
        should.raise do
          response(100)
        end
      end

      it 'returns the commit failed due to a timeout' do
        {
          Errno::ETIMEDOUT => 'Connection timed out - connect(2)',
          Net::OpenTimeout => 'execution expired',
          Net::ReadTimeout => 'Does not have a message',
          Timeout::Error   => 'execution expired'
        }.each do |error_class, message|
          res = response do
            error = error_class.new
            # ETIMEDOUT adds more useless text by itself, omitting for test purposes.
            error.stubs(:message).returns(message)
            raise error
          end
          res.should.not.be.success
          res.should.not.be.failed_on_our_side
          res.should.not.be.failed_on_their_side
          res.should.be.failed_due_to_timeout
          res.timeout_error.should == "[#{error_class.name}] #{message}"
        end
      end
    end
  end
end
