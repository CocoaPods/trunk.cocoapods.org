require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe "Owner" do
    before do
      @owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny')
    end

    describe "concerning validations" do
      it "raises if for whatever reason a duplicate email gets inserted into the DB" do
        should.raise Sequel::UniqueConstraintViolation do
          Owner.create(:email => 'jenny@example.com', :name => 'Penny')
        end
      end
    end

    describe "in general" do
      it "coerces to JSON" do
        json = JSON.parse(@owner.to_json)
        json.keys.sort.should == %w(created_at email name)
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
        owner = Owner.new(:email => " #{email.upcase} ")
        owner.email.should == email
      end
    end

    describe "concerning sessions" do
      before do
        Mail::TestMailer.deliveries.clear
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
        mail.body.decoded.should.include "https://example.com/#{@owner.sessions_dataset.valid.last.verification_token}"
      end

      it "sends a new session confirmation email if the owner was not just created" do
        owner = Owner.find(:id => @owner.id)
        owner.create_session!('https://example.com/%s')
        mail = Mail::TestMailer.deliveries.last
        mail.to.should == [@owner.email]
        mail.subject.should == '[CocoaPods] Confirm your session.'
        mail.body.decoded.should.include 'confirm your CocoaPods session'
        mail.body.decoded.should.include "https://example.com/#{@owner.sessions_dataset.valid.last.verification_token}"
      end
    end

    describe "concerning pods it owns" do
      it "adds a pod" do
        pod = @owner.add_pod(:name => 'AFNetworking')
        Pod.find(:id => pod.id).owners.should == [@owner]
      end
    end
  end
end
