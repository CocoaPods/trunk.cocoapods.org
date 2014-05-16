require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe SessionVerificationController do
    before do
      header 'Content-Type', 'text/html'
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
    end

    it 'verifies a session and nulls the verification token' do
      session = Session.create(:owner => @owner, :created_from_ip => '1.2.3.4')
      get "/verify/#{session.verification_token}"
      last_response.status.should == 200
      session.reload.should.be.verified
      session.verification_token.should.be.nil
      last_response.body.should.not.include session.token
    end

    it 'does not verify an invalid session' do
      session = Session.create(:owner => @owner, :created_from_ip => '1.2.3.4')
      session.update(:valid_until => 1.second.ago)
      get "/verify/#{session.verification_token}"
      last_response.status.should == 404
      session.reload.should.not.be.verified
    end
  end
end
