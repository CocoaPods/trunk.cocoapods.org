require File.expand_path('../../../spec_helper', __FILE__)

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
    extend SpecHelpers::Response

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
      yaml_response.should == {
        'error' => {
          'errors'   => ['Missing required attribute `name`.', 'The version of the spec should be higher than 0.'],
          'warnings' => ['Missing required attribute `license`.', 'Missing license type.']
        }
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

    it "creates a submission job and log message once a new pod version is created" do
      lambda {
        post '/pods', spec.to_yaml
      }.should.change { SubmissionJob.count }
      job = Pod.first(:name => spec.name).versions.first.submission_jobs.last
      job.owner.should == @owner
      job.specification_data.should == spec.to_yaml
      job.log_messages.map(&:message).should == ['Submitted.']
    end

    it "does not allow a push for an existing pod version if it's published" do
      @owner.add_pod(:name => spec.name).add_version(:name => spec.version.to_s, :published => true)
      lambda {
        post '/pods', spec.to_yaml
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 409
      last_response.location.should == 'https://example.org/pods/AFNetworking/versions/1.2.0'
    end

    it "does not allow a push for an existing pod version while a job is in progress" do
      version = @owner.add_pod(:name => spec.name).add_version(:name => spec.version.to_s)
      version.add_submission_job(:succeeded => false)
      version.add_submission_job(:succeeded => nil)
      lambda {
        post '/pods', spec.to_yaml
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 409
      last_response.location.should == 'https://example.org/pods/AFNetworking/versions/1.2.0'
    end

    it "does allow a push for an existing pod version if the previous jobs have failed" do
      version = @owner.add_pod(:name => spec.name).add_version(:name => spec.version.to_s)
      version.add_submission_job(:succeeded => false)
      version.add_submission_job(:succeeded => false)
      lambda {
        lambda {
          post '/pods', spec.to_yaml
        }.should.not.change { PodVersion.count }
      }.should.change { SubmissionJob.count }
      last_response.status.should == 202
      last_response.location.should == 'https://example.org/pods/AFNetworking/versions/1.2.0'
    end

    before do
      @version = Pod.create(:name => spec.name).add_version(:name => spec.version.to_s)
      @job = @version.add_submission_job(:specification_data => spec.to_yaml)
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
      version.add_submission_job(:specification_data => spec.to_yaml)
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.status.should == 202
    end
  end

  describe APIController, "concerning authorization" do
    extend SpecHelpers::Authentication
    extend SpecHelpers::Response

    def spec
      @spec ||= fixture_specification('AFNetworking.podspec')
    end

    before do
      sign_in!
      header 'Content-Type', 'text/yaml'
    end

    it "allows a push for an non-existing pod and makes the authenticated owner the owner" do
      lambda {
        lambda {
          post '/pods', spec.to_yaml
        }.should.change { Pod.count }
      }.should.change { PodVersion.count }
      Pod.find(:name => spec.name).owners.should == [@owner]
    end

    it "allows a push for an existing pod owned by the authenticated owner" do
      @owner.add_pod(:name => spec.name)
      lambda {
        lambda {
          post '/pods', spec.to_yaml
        }.should.not.change { Pod.count }
      }.should.change { PodVersion.count }
    end

    it "does not allow a push for an existing pod not owned by the authenticated owner" do
      other_owner = Owner.create(:email => 'jenny@example.com')
      other_owner.add_pod(:name => spec.name)
      lambda {
        lambda {
          post '/pods', spec.to_yaml
        }.should.not.change { Pod.count }
      }.should.not.change { PodVersion.count }
      last_response.status.should == 403
    end

    it "adds an owner to the pod's owners" do
      pod = @owner.add_pod(:name => spec.name)
      other_owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny')
      put '/pods/AFNetworking/owners', { 'email' => other_owner.email }.to_yaml
      last_response.status.should == 200
      pod.owners.should == [@owner, other_owner]
    end

    it "does not allow to add an owner to a pod that's not owned by the authenticated owner" do
      other_owner = Owner.create(:email => 'jenny@example.com')
      pod = other_owner.add_pod(:name => spec.name)
      put '/pods/AFNetworking/owners', { 'email' => @owner.email }.to_yaml
      last_response.status.should == 403
      pod.owners.should == [other_owner]
    end
  end
end
