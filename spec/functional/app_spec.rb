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

    it "fails with invalid spec data" do
      lambda do
        post '/pods', "---\nsomething: else\n"
      end.should.not.change { Pod.count + PodVersion.count }
      last_response.status.should == 400
    end

    it "creates new pod and version records" do
      lambda do
        lambda do
          post '/pods', spec.to_yaml
        end.should.change { Pod.count }
      end.should.change { PodVersion.count }
      last_response.status.should == 202
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
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
