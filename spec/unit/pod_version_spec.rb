require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod_version'

module Pod::TrunkApp
  describe "PodVersion" do
    describe "concerning submission progress state" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "initializes with an unpublished state" do
        @version.should.not.be.published
      end
    end
  end
end
