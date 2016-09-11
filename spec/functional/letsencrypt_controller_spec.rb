require File.expand_path('../../spec_helper', __FILE__)

ENV['ACME_KEY_1']   = '123sadaf2342rfsdf'
ENV['ACME_TOKEN_1'] = 'fkjsdbfnkjnk354nrfwegsdfg'

module Pod::TrunkApp
  describe LetsEncryptController do
    test_controller! LetsEncryptController

    # This controller is scoped to "/.well-known/" inside the app router

    it 'handles ACME responses using known environment vars' do
      get 'https://example.org/acme-challenge/' + ENV['ACME_TOKEN_1']
      last_response.should.be.ok
      last_response.body.should == ENV['ACME_KEY_1']
      last_response.headers['Content-Type'].should == 'text/plain'
    end

    it '404s for responses without known environment vars' do
      get 'https://example.org/acme-challenge/orta'
      last_response.status.should == 404
      last_response.body.should == ''
    end
  end
end
