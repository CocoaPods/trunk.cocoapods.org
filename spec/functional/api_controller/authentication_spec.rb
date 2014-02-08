require File.expand_path('../../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe APIController, "concerning registration" do
    extend SpecHelpers::Authentication
    extend SpecHelpers::Response

    before do
      @name = 'Jenny'
      @email = 'jenny@example.com'
      header 'Content-Type', 'application/json; charset=utf-8'
    end

    it "sees a useful error message when posting invalid JSON data" do
      post '/register', '{'
      last_response.status.should == 400
      json_response['error'].should == "Invalid JSON data provided."
    end

    it "creates a new owner on first registration" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_json
      }.should.change { Owner.count }
      last_response.status.should == 201

      owner = Owner.find_by_email(@email)
      owner.email.should == @email
      owner.name.should == @name
    end

    it "creates a new session on first registration" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_json
      }.should.change { Session.count }
      last_response.status.should == 201

      session = Owner.find_by_email(@email).sessions_dataset.valid.last
      json_response['token'].should == session.token
      json_response['valid_until'].should == session.valid_until.to_s
      json_response['verified'].should == false
    end

    it "shows validation errors if creating an owner fails" do
      lambda {
        post '/register', { 'email' => nil, 'name' => nil }.to_json
      }.should.not.change { Owner.count + Session.count }
      last_response.status.should == 422
      json_response['error'].keys.sort.should == %w(email name)
    end

    it "does not create a new owner or session in case emailing raises an error" do
      Mail::Message.any_instance.stubs(:deliver).raises
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_json
      }.should.not.change { Owner.count + Session.count }
      last_response.status.should == 500
    end

    it "creates only a new session on subsequent registrations" do
      owner = Owner.create(:email => @email, :name => @name)
      owner.add_session({})
      lambda {
        lambda {
          post '/register', { 'email' => @email, 'name' => nil }.to_json
        }.should.not.change { Owner.count }
      }.should.change { Session.count }
      owner.reload.sessions.size.should == 2
      owner.name.should == @name
    end

    it "updates the owner's name in case it is specified on subsequent registrations" do
      owner = Owner.create(:email => @email, :name => @name)
      post '/register', { 'email' => @email, 'name' => 'Changed' }.to_json
      owner.reload.name.should == 'Changed'
    end

    it "does not create a new session in case emailing raises an error" do
      owner = Owner.create(:email => @email, :name => @name)
      Mail::Message.any_instance.stubs(:deliver).raises
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_json
      }.should.not.change { Session.count }
      last_response.status.should == 500
    end

    it "sends an email with the session verification link" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_json
      }.should.change { Mail::TestMailer.deliveries.size }
      last_response.status.should == 201

      mail = Mail::TestMailer.deliveries.last
      mail.to.should == [@email]
      session = Owner.find_by_email(@email).sessions_dataset.valid.last
      mail.body.decoded.should.include "https://example.org/sessions/verify/#{session.verification_token}"
    end
  end

  describe APIController, "concerning sessions" do
    extend SpecHelpers::Response
    extend SpecHelpers::Authentication

    before do
      header 'Content-Type', 'text/plain'
    end

    it "verifies a session" do
      session = Session.create(:owner => Owner.create(:email => 'appie@example.com', :name => 'Appie Duran'))
      get "/sessions/verify/#{session.verification_token}"
      last_response.status.should == 200
      session.reload.verified.should == true
    end

    it "does not verify an invalid session" do
      session = Session.create(:owner => Owner.create(:email => 'appie@example.com', :name => 'Appie Duran'))
      session.update(:valid_until => 1.second.ago)
      get "/sessions/verify/#{session.verification_token}"
      last_response.status.should == 404
      session.reload.verified.should == false
    end

    it "does not verify an unexisting session" do
      get "/sessions/verify/doesnotexist"
      last_response.status.should == 404
    end

    before do
      header 'Content-Type', 'text/json'
    end

    it "shows an overview of all active sessions" do
      session = sign_in!
      owner = session.owner
      owner.add_session({})

      get '/sessions'
      last_response.status.should == 200
      json_response.should == JSON.parse(owner.sessions.map(&:public_attributes).to_json)
    end

    it "clears all active sessions except the currently used one" do
      session = sign_in!
      owner = session.owner
      owner.add_session({})
      lambda {
        delete '/sessions'
      }.should.change { Session.count }
      last_response.status.should == 200

      owner.sessions.should == [session.reload]
      json_response.should == JSON.parse(session.public_attributes.to_json)
    end

    it "prolongs a session each time it's required" do
      session = sign_in!
      session.update(:valid_until => 10.seconds.from_now)
      get '/me'
      session.reload.valid_until.should > 10.seconds.from_now
    end
  end

  describe APIController, "concerning authentication" do
    extend SpecHelpers::Response
    extend SpecHelpers::Authentication

    before do
      header 'Content-Type', 'application/json; charset=utf-8'
    end

    it "allows access with a valid verified session belonging to an owner" do
      session = create_session_with_owner
      get '/me', nil, { 'HTTP_AUTHORIZATION' => "Token #{session.token}"}
      last_response.status.should == 200
    end

    it "does not allow access when no authentication token is supplied" do
      get '/me'
      last_response.status.should == 401
      json_response['error'].should == "Please supply an authentication token."
    end

    it "does not allow access when an invalid authentication token is supplied" do
      get '/me', nil, { 'HTTP_AUTHORIZATION' => 'Token invalid' }
      last_response.status.should == 401
      json_response['error'].should == "Authentication token is invalid or unverified."
    end

    it "does not allow access when an unverified authentication token is supplied" do
      session = create_session_with_owner
      session.update(:verified => false)
      get '/me', nil, { 'HTTP_AUTHORIZATION' => "Token #{session.token}"}
      last_response.status.should == 401
      json_response['error'].should == "Authentication token is invalid or unverified."
    end
  end
end

