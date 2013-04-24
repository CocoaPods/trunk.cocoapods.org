require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "PodVersion" do
    describe "concerning submission progress state" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "initializes with a new state" do
        @version.should.be.submitted
        @version.should.not.be.published
      end
    end
  end
end
