require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod'

module Pod::TrunkApp
  describe Pod do
    describe "concerning validations" do
      it "raises if for whatever reason a duplicate name gets inserted into the DB" do
        Pod.create(:name => 'AFNetworking')
        should.raise Sequel::UniqueConstraintViolation do
          Pod.create(:name => 'AFNetworking')
        end
      end
    end

    describe "in general" do
      before do
        @owner = Owner.create(:email => 'jenny@example.com')
      end

      it "adds an owner" do
        owner2 = Owner.create(:email => 'appie@example.com')
        pod = @owner.add_pod(:name => 'AFNetworking')
        pod.add_owner(owner2)
        pod.owners.should == [@owner, owner2]
      end

      it "does not find an unexisting pod" do
        Pod.find_by_name_and_owner('CocoaLumberjack', @owner).should == nil
      end

      it "returns an existing pod if it's owned by nobody yet" do
        pod = Pod.create(:name => 'AFNetworking')
        Pod.find_by_name_and_owner('AFNetworking', @owner).should == pod
      end

      it "returns an existing pod if it's owned by the specified owner" do
        pod = @owner.add_pod(:name => 'AFNetworking')
        Pod.find_by_name_and_owner('AFNetworking', @owner).should == pod
      end

      it "does not return a pod if it's owned by another user" do
        other_owner = Owner.create(:email => 'appie@example.com')
        other_owner.add_pod(:name => 'AFNetworking')
        Pod.find_by_name_and_owner('AFNetworking', @owner).should == nil
      end

      it "yields the 'no access allowed' block if it's owned by another user" do
        other_owner = Owner.create(:email => 'appie@example.com')
        other_owner.add_pod(:name => 'AFNetworking')
        yielded = false
        Pod.find_by_name_and_owner('AFNetworking', @owner) { yielded = true }
        yielded.should == true
      end
    end
  end
end

