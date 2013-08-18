require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod'

module Pod::TrunkApp
  describe Pod do
    it "adds an owner" do
      owner1 = Owner.create(:email => 'jenny@example.com')
      owner2 = Owner.create(:email => 'appie@example.com')
      pod = owner1.add_pod(:name => 'AFNetworking')
      pod.add_owner(owner2)
      pod.owners.should == [owner1, owner2]
    end
  end
end

