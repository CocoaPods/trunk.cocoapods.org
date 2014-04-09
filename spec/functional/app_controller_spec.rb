require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  class AppController
    get '/ping' do
      'ok'
    end
  end

  describe AppController do
    test_controller! AppController

    it 'allows https URLs' do
      get 'https://example.org/ping'
      last_response.should.be.ok
    end

    it 'allows forwarded HTTP URLs' do
      get 'http://example.org/ping', {}, 'HTTP_X_FORWARDED_PROTO' => 'https'
      last_response.should.be.ok
    end

    it 'redirects HTTP URLs to HTTPS' do
      get 'http://example.org/ping'
      last_response.should.be.redirect?
      last_response.headers['Location'].should == 'https://example.org/ping'
    end
  end
end
