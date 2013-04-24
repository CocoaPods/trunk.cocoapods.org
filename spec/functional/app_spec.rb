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

module Pod::PushApp
  describe "App" do
    extend Rack::Test::Methods

    def app
      App
    end

    def spec
      @spec ||= fixture_specification('AFNetworking.podspec')
    end

    before do
      @spec = nil
      header 'Content-Type', 'text/yaml'
      GitHub.stubs(:create_pull_request)
    end

    it "only accepts YAML" do
      header 'Content-Type', 'application/json'
      post '/pods'
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
      last_response.location.should == 'http://example.org/pods/AFNetworking/versions/1.2.0'
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it "does not allow a push for an existing pod version" do
      Pod.create(:name => spec.name).add_version(:name => spec.version.to_s)
      lambda {
        post '/pods', spec.to_yaml
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 409
      last_response.location.should == 'http://example.org/pods/AFNetworking/versions/1.2.0'
    end

    it "creates a submission job and log message once a new pod version is created" do
      post '/pods', spec.to_yaml
      job = Pod.first(:name => spec.name).versions.first.submission_job
      job.log_messages.map(&:message).should == ['Submitted']
    end

    it "returns the status of the submission flow" do
      job = Pod.create(:name => spec.name).add_version(:name => spec.version.to_s).submission_job
      job.add_log_message(:message => 'Another message')
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.body.should == job.log_messages.map do |log_message|
        { log_message.created_at => log_message.message }
      end.to_yaml
    end

    it "returns that the pod version is not yet published" do
      Pod.create(:name => spec.name).add_version(:name => spec.version.to_s)
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.status.should == 102
    end

    it "returns that the pod version is published" do
      Pod.create(:name => spec.name).add_version(:name => spec.version.to_s, :state => 'published')
      get '/pods/AFNetworking/versions/1.2.0'
      last_response.status.should == 200
    end

    it "returns a 404 when a pod or version can't be found" do
      get '/pods/AFNetworking/versions/0.2.1'
      last_response.status.should == 404
      get '/pods/FANetworking/versions/1.2.0'
      last_response.status.should == 404
    end

    #it "creates a pull-request for the specification" do
      #PodVersion.any_instance.stubs(:id).returns(42)
      #GitHub.expects(:create_pull_request).with('[Add] AFNetworking (1.2.0)', 'merge-42', 'merge-42', 'AFNetworking/1.2.0/AFNetworking.podspec', fixture_read('AFNetworking.podspec')).returns(3)
      #post '/pods', spec.to_yaml
      #last_response.should.be.ok
      #last_response.location.should == "https://github.com/#{GitHub::REPO}/pull/3"
      #Pod.first(:name => spec.name).versions.first.should.be.submitted_as_pull_request
    #end
  end
end
