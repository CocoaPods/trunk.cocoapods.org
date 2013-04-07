require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "Pod" do
    describe "::find_or_create_by_name" do
      it "returns a library matching the specified name" do
        pod = Pod.create(:name => 'AFNetworking')
        count = Pod.count
        Pod.find_or_create_by_name('AFNetworking').should == pod
        Pod.count.should == count
      end

      it "creates and returns a new record when there is no existing match for the library's name" do
        count = Pod.count
        Pod.find_or_create_by_name('AFNetworking').name.should == 'AFNetworking'
        Pod.count.should == count + 1
      end
    end
  end
end
