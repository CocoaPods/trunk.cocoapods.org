require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "SubmissionJob" do
    describe "concerning submission progress state" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "initializes with a new state" do
        @version.submission_job.should.be.submitted
      end
    end
  end
end

