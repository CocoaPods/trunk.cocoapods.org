require File.expand_path('../../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe APIController, "concerning registration" do
    extend SpecHelpers::Authentication
    extend SpecHelpers::Response

    before do
      @name = 'Jenny'
      @email = 'jenny@example.com'
      header 'Content-Type', 'text/yaml'
    end

    it "sees a useful error message when posting blank owner data" do
      post '/register'
      last_response.status.should == 422
      yaml = yaml_response
      yaml.keys.should == %w(error)
      yaml['error'].should == "Please send the owner email address in the body of your post."
    end

    it "creates a new owner on first registration" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_yaml
      }.should.change { Owner.count }
      last_response.status.should == 201

      owner = Owner.find_by_email(@email)
      owner.email.should == @email
      owner.name.should == @name
    end

    it "creates a new session on first registration" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_yaml
      }.should.change { Session.count }
      last_response.status.should == 201

      session = Owner.find_by_email(@email).sessions_dataset.valid.last
      yaml_response['token'].should == session.token
      yaml_response['valid_until'].should == session.valid_until
      yaml_response['verified'].should == false
    end

    it "creates only a new session on subsequent registrations" do
      owner = Owner.create(:email => @email)
      owner.add_session({})
      lambda {
        lambda {
          post '/register', { 'email' => @email, 'name' => @name }.to_yaml
        }.should.not.change { Owner.count }
      }.should.change { Session.count }
      owner.reload.sessions.size.should == 2
    end

    it "sends an email with the session verification link" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_yaml
      }.should.change { Mail::TestMailer.deliveries.size }
      last_response.status.should == 201

      mail = Mail::TestMailer.deliveries.last
      mail.to.should == [@email]
      session = Owner.find_by_email(@email).sessions_dataset.valid.last
      mail.body.decoded.should.include "https://example.org/sessions/verify/#{session.verification_token}"
    end

    it "shows an overview of all active sessions" do
      session = sign_in!
      owner = session.owner
      sessions = [session, owner.add_session({})]

      get '/sessions'
      last_response.status.should == 200
      yaml_response.should == sessions.map(&:public_attributes)
    end

    it "clears all active sessions except the currently used one" do
      session = sign_in!
      owner = session.owner
      owner.add_session({})
      lambda {
        delete '/sessions'
      }.should.change { Session.count }
      last_response.status.should == 200

      owner.sessions.should == [session]
      yaml_response.should == session.public_attributes
    end

    before do
      header 'Content-Type', 'text/plain'
    end

    it "verifies a session" do
      session = Session.create
      get "/sessions/verify/#{session.verification_token}"
      last_response.status.should == 200
      session.reload.verified.should == true
    end

    it "does not verify an invalid session" do
      session = Session.create
      session.update(:valid_until => 1.second.ago)
      get "/sessions/verify/#{session.verification_token}"
      last_response.status.should == 404
      session.reload.verified.should == false
    end

    it "does not verify an unexisting session" do
      get "/sessions/verify/doesnotexist"
      last_response.status.should == 404
    end
  end

  describe APIController, "concerning authentication" do
    extend SpecHelpers::Response
    extend SpecHelpers::Authentication

    before do
      header 'Content-Type', 'text/yaml'
    end

    it "allows access with a valid verified session belonging to an owner" do
      session = create_session_with_owner
      get '/me', nil, { 'HTTP_AUTHORIZATION' => "Token #{session.token}"}
      last_response.status.should == 200
    end

    it "does not allow access when no authentication token is supplied" do
      get '/me'
      last_response.status.should == 401
      yaml_response.should == "Please supply an authentication token."
    end

    it "does not allow access when an invalid authentication token is supplied" do
      get '/me', nil, { 'HTTP_AUTHORIZATION' => 'Token invalid' }
      last_response.status.should == 401
      yaml_response.should == "Authentication token is invalid or unverified."
    end

    it "does not allow access when an unverified authentication token is supplied" do
      session = create_session_with_owner
      session.update(:verified => false)
      get '/me', nil, { 'HTTP_AUTHORIZATION' => "Token #{session.token}"}
      last_response.status.should == 401
      yaml_response.should == "Authentication token is invalid or unverified."
    end
  end
end

