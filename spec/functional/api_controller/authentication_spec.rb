require File.expand_path('../../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe APIController, "an unauthenticated consumer, which is not known to the system" do
    extend SpecHelpers::Response

    before do
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

    it "creates a new session" do
      post '/register', { 'email' => @email }.to_yaml
      last_response.status.should == 201
      yaml_response['email'].should == @email
    end
  end

  describe APIController, "authentication" do
    extend SpecHelpers::Response
    extend SpecHelpers::Authentication

    before do
      header 'Content-Type', 'text/yaml'
    end

    it "allows access with a valid session belonging to an owner" do
      session = create_session_with_owner
      get '/me', nil, { 'Authorization' => "Token #{session.token}"}
      last_response.status.should == 200
    end

    it "does not allow access when no authentication token is supplied" do
      get '/me'
      last_response.status.should == 401
      yaml_response.should == "Please supply an authentication token."
    end

    it "does not allow access when an invalid authentication token is supplied" do
      get '/me', nil, { 'Authorization' => 'Token invalid' }
      last_response.status.should == 401
      yaml_response.should == "Authentication token is invalid."
    end
  end
end
