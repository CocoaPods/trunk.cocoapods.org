require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "Owner" do
    before do
      @owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny')
    end

    it "coerces to YAML" do
      yaml = YAML.load(@owner.to_yaml)
      yaml.keys.sort.should == %w(created_at email id name)
    end
  end
end
