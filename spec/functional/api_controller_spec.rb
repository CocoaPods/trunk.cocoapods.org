require File.expand_path('../../spec_helper', __FILE__)

module Fixtures
  # Taken from https://github.com/dtao/safe_yaml/blob/master/README.md#explanation
  class ClassBuilder
    def self.this_should_not_be_called!
    end

    def []=(key, value)
      self.class.class_eval <<-EOS
        def #{key}
          #{value}
        end
      EOS
    end
  end
end

module Pod::TrunkApp
  describe APIController, "with an authenticated owner" do
    extend SpecHelpers::Authentication

    def spec
      @spec ||= fixture_specification('AFNetworking.podspec')
    end

    before do
      sign_in!

      @spec = nil
      header 'Content-Type', 'text/yaml'
    end

    it "only accepts YAML" do
      header 'Content-Type', 'application/json'
      post '/pods', {}, { 'HTTPS' => 'on' }
      last_response.status.should == 415
    end

    it "does not allow unsafe YAML to load" do
      yaml = <<-EOYAML
--- !ruby/hash:Fixtures::ClassBuilder
"foo; end; this_should_not_be_called!; def bar": "baz"
EOYAML
      Fixtures::ClassBuilder.expects(:this_should_not_be_called!).never
      post '/pods', yaml
    end

    it "fails with data other than serialized spec data" do
      lambda {
        post '/pods', ''
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 400

      lambda {
        post '/pods', "---\nsomething: else\n"
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 422
    end

    it "fails with a spec that does not pass a quick lint" do
      spec.name = nil
      spec.version = nil
      spec.license = nil

      lambda {
        post '/pods', spec.to_yaml
      }.should.not.change { Pod.count + PodVersion.count }

      last_response.status.should == 422
      YAML.load(last_response.body).should == {
        'errors'   => ['Missing required attribute `name`.', 'The version of the spec should be higher than 0.'],
        'warnings' => ['Missing required attribute `license`.', 'Missing license type.']
      }
    end

    it "creates new pod and version records" do
      lambda {
        lambda {
          post '/pods', spec.to_yaml
        }.should.change { Pod.count }
      }.should.change { PodVersion.count }
      last_response.status.should == 202
      last_response.location.should == 'https://example.org/pods/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it "does not allow a push for an existing pod version" do
      Pod.create(:name => spec.name).add_version(:name => spec.version.to_s)
      lambda {
        post '/pods', spec.to_yaml
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 409
      last_response.location.should == 'https://example.org/pods/AFNetworking/versions/1.2.0'
    end

    it "creates a submission job and log message once a new pod version is created" do
      post '/pods', spec.to_yaml
      job = Pod.first(:name => spec.name).versions.first.submission_jobs.last
      job.specification_data.should == spec.to_yaml
      job.log_messages.map(&:message).should == ['Submitted.']
    end

    before do
      @version = Pod.create(:name => spec.name).add_version(:name => spec.version.to_s)
      @job = @version.add_submission_job(:specification_data => spec.to_yaml, :pull_request_number => 3)
    end

    it "returns the status of the submission flow" do
      @job.add_log_message(:message => 'Another message')
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.body.should == @job.log_messages.map do |log_message|
        { log_message.created_at => log_message.message }
      end.to_yaml
    end

    it "returns that the pod version is not yet published" do
      get '/pods/AFNetworking/versions/1.2.0'
      # last_response.status.should == 102
      last_response.status.should == 202
    end

    it "returns that the pod version is published" do
      @version.update(:published => true)
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.status.should == 200
    end

    it "returns that the submission job failed" do
      @job.update(:succeeded => false)
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.status.should == 404
    end

    it "returns a 404 when a pod or version can't be found" do
      get '/pods/AFNetworking/versions/0.2.1'
      last_response.status.should == 404
      get '/pods/FANetworking/versions/1.2.0'
      last_response.status.should == 404
    end
  end

  describe APIController, "an unauthenticated consumer" do
    before do
      @email = 'jenny@example.com'
      header 'Content-Type', 'text/yaml'
    end

    it "is not allowed to post a new pod" do
      spec = fixture_specification('AFNetworking.podspec')
      lambda {
        lambda {
          post '/pods', spec.to_yaml
        }.should.not.change { Pod.count }
      }.should.not.change { PodVersion.count }
      last_response.status.should == 401
    end

    it "is allowed to GET status of a pod version" do
      spec = fixture_specification('AFNetworking.podspec')
      version = Pod.create(:name => spec.name).add_version(:name => spec.version.to_s)
      version.add_submission_job(:specification_data => spec.to_yaml, :pull_request_number => 3)
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.status.should == 202
    end
  end

  describe APIController, "concerning registration" do
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

    it "creates a new owner" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_yaml
      }.should.change { Owner.count }
      last_response.status.should == 201

      owner = Owner.find_by_email(@email)
      owner.email.should == @email
      owner.name.should == @name
    end

    it "creates a new session" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_yaml
      }.should.change { Session.count }
      last_response.status.should == 201

      session = Owner.find_by_email(@email).sessions_dataset.valid.last
      yaml_response['token'].should == session.token
      yaml_response['valid_until'].should == session.valid_until
      yaml_response['verified'].should == false
    end

    it "sends an email with the session confirmation link" do
      lambda {
        post '/register', { 'email' => @email, 'name' => @name }.to_yaml
      }.should.change { Mail::TestMailer.deliveries.size }
      last_response.status.should == 201

      mail = Mail::TestMailer.deliveries.last
      mail.to.should == [@email]
      session = Owner.find_by_email(@email).sessions_dataset.valid.last
      mail.body.decoded.should.include "https://example.org/sessions/confirm/#{session.token}"
    end

    before do
      header 'Content-Type', 'text/plain'
    end

    it "confirms a session" do
      session = Session.create
      get "/sessions/confirm/#{session.token}"
      last_response.status.should == 200
      session.reload.verified.should == true
    end

    it "does not confirm an invalid session" do
      session = Session.create
      session.update(:valid_until => 1.second.ago)
      get "/sessions/confirm/#{session.token}"
      last_response.status.should == 404
      session.reload.verified.should == false
    end

    it "does not confirm an unexisting session" do
      get "/sessions/confirm/doesnotexist"
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

