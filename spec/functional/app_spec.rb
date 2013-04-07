require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "App" do
    extend Rack::Test::Methods

    def app
      App
    end

    it "creates new pod and version records" do
      spec = fixture_specification('AFNetworking.podspec')
      post '/pods', { :specification => fixture_read('AFNetworking.podspec'), :yaml => spec.to_yaml }
      last_response.should.be.ok
      Pod.first(:name => spec.name).versions.map(&:name).should == [spec.version.to_s]
    end
  end
end
