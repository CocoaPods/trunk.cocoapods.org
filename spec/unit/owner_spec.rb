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

    it "finds itself with an email address" do
      owner = Owner.find_or_create_by_email(@owner.email)
      owner.should.not.be.new
      owner.email.should == @owner.email
    end

    it "creates itself with an email address" do
      email = 'janny@example.com'
      owner = Owner.find_or_create_by_email(email)
      owner.should.not.be.new
      owner.email.should == email
    end

    it "normalizes the email address when finding by email address" do
      owner = Owner.find_or_create_by_email(" #{@owner.email.upcase} ")
      owner.should.not.be.new
      owner.email.should == @owner.email
    end

    it "normalizes the email address when creating by email address" do
      email = 'janny@example.com'
      owner = Owner.find_or_create_by_email(" #{email.upcase} ")
      owner.should.not.be.new
      owner.email.should == email
    end
  end
end
