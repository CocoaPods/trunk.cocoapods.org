require File.expand_path('../../../spec_helper', __FILE__)

module SpecHelpers
  module Response
    def yaml_response
      YAML.load(last_response.body)
    end
  end

  module Authentication
  end
end

module Pod::PushApp
  describe "App" do
    def app
      App
    end

    describe "authentication" do
      extend Rack::Test::Methods
      extend SpecHelpers::Response
      extend SpecHelpers::Authentication

      before do
        header 'Content-Type', 'text/yaml'
      end

      it "allows access with a valid session belonging to an owner" do
        owner = Owner.create
        session = Session.create
        owner.add_session(session)

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
end
