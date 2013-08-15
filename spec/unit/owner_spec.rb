require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe "Owner" do
    before do
      Mail::TestMailer.deliveries.clear
      @owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny')
    end

    it "coerces to YAML" do
      yaml = YAML.load(@owner.to_yaml)
      yaml.keys.sort.should == %w(created_at email id name)
    end

    it "finds itself with an email address" do
      owner = Owner.find_by_email(@owner.email)
      owner.email.should == @owner.email
    end

    it "normalizes the email address when finding by email address" do
      owner = Owner.find_by_email(" #{@owner.email.upcase} ")
      owner.email.should == @owner.email
    end

    it "normalizes the email address when assigning the email address" do
      email = 'janny@example.com'
      owner = Owner.create(:email => " #{email.upcase} ")
      owner.email.should == email
    end

    it "adds a new session" do
      session = nil
      lambda {
        session = @owner.create_session!('https://example.com/%s')
      }.should.change { Session.count }
      @owner.sessions_dataset.valid.to_a.should == [session]
    end

    it "sends a registration confirmation email if the owner was just created" do
      @owner.reload.create_session!('https://example.com/%s')
      mail = Mail::TestMailer.deliveries.last
      mail.to.should == [@owner.email]
      mail.subject.should == '[CocoaPods] Confirm your registration.'
      mail.body.decoded.should.include 'confirm your registration with CocoaPods'
      mail.body.decoded.should.include "https://example.com/#{@owner.sessions_dataset.valid.last.token}"
    end

    it "sends a new session confirmation email if the owner was not just created" do
      owner = Owner.find(:id => @owner.id)
      owner.create_session!('https://example.com/%s')
      mail = Mail::TestMailer.deliveries.last
      mail.to.should == [@owner.email]
      mail.subject.should == '[CocoaPods] Confirm your session.'
      mail.body.decoded.should.include 'confirm your CocoaPods session'
      mail.body.decoded.should.include "https://example.com/#{@owner.sessions_dataset.valid.last.token}"
    end
  end
end
