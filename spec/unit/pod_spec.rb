require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod'

module Pod::TrunkApp
  describe Pod do
    before do
      @owner = Owner.create(:email => 'jenny@example.com')
    end

    it "adds an owner" do
      owner2 = Owner.create(:email => 'appie@example.com')
      pod = @owner.add_pod(:name => 'AFNetworking')
      pod.add_owner(owner2)
      pod.owners.should == [@owner, owner2]
    end

    it "does not create a pod if it doesn't exist yet" do
      pod = nil
      yielded = false
      lambda {
        pod = Pod.find_by_name_and_owner('AFNetworking', @owner) { yielded = true; nil }
      }.should.not.change { Pod.count }
      pod.should == nil
      yielded.should == false
    end

    it "creates a pod if it did not exist yet" do
      pod = nil
      yielded = false
      lambda {
        pod = Pod.find_or_create_by_name_and_owner('AFNetworking', @owner) { yielded = true; nil }
      }.should.change { Pod.count }
      pod.name.should == 'AFNetworking'
      pod.owners.should == [@owner]
      yielded.should == false
    end

    it "returns an existing pod if it's owned by the specified owner" do
      pod = @owner.add_pod(:name => 'AFNetworking')
      found_pod = nil
      yielded = false
      lambda {
        found_pod = Pod.find_by_name_and_owner('AFNetworking', @owner) { yielded = true; nil }
      }.should.not.change { Pod.count }
      found_pod.should == pod
      yielded.should == false
    end

    it "does not return a pod if it's not owned by the specified owner" do
      other_owner = Owner.create(:email => 'appie@example.com')
      other_owner.add_pod(:name => 'AFNetworking')
      found_pod = nil
      yielded = false
      lambda {
        found_pod = Pod.find_by_name_and_owner('AFNetworking', @owner) { yielded = true; nil }
      }.should.not.change { Pod.count }
      found_pod.should == nil
      yielded.should == true
    end
  end
end

