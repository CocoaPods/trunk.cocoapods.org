require File.expand_path('../../spec_helper', __FILE__)

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
      GitHub.stubs(:create_pull_request)
    end

    it "only accepts YAML" do
      header 'Content-Type', 'application/json'
      post '/pods'
      last_response.status.should == 406
    end

    it "creates new pod and version records" do
      header 'Content-Type', 'text/yaml'
      post '/pods', spec.to_yaml
      last_response.should.be.ok
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
