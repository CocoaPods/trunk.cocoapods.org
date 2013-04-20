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
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end

    it "does not allow a push for an existing pod version" do
      Pod.create(:name => spec.name).add_version(:name => spec.version.to_s)
      lambda {
        post '/pods', spec.to_yaml
      }.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 409
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
