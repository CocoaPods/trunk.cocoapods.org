require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "PodVersion" do
    describe "concerning submission progress state" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "initializes with a `new` state" do
        @version.state.should == nil
        @version.should.not.be.submitted_as_pull_request
      end

      it "changes state to indicate it has been submitted to GitHub as a pull-request" do
        @version.submitted_as_pull_request!
        @version.state.should == 'submitted_as_pull_request'
        @version.should.be.submitted_as_pull_request
      end
    end
  end
end
