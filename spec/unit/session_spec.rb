require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/session'

module Pod::TrunkApp
  describe Session do
    describe "when initializing" do
      it "is not verified yet" do
        Session.create.verified.should == false
      end

      it "automatically creates a token and a verification token for itself" do
        session = Session.new
        session.token.length.should == 32
        session.verification_token.length.should == 8
      end

      it "allows you to configure the token length" do
        session = Session.new(:token_length => 2)
        session.token.length.should == 2
      end

      it "has a default validity time" do
        Session.new.valid_for.should == 128
      end

      it "sets a default expiration date" do
        expected = Time.now + Session.new.valid_for.days
        Session.new.valid_until.to_s.should == expected.to_s
      end

      it "allows you to set a different validity time" do
        Session.new(:valid_for => 7).valid_for.should == 7
      end

      it "sets a default expiration date based on the validity time" do
        valid_for = 23
        expected = Time.now + valid_for.days
        Session.new(:valid_for => valid_for).valid_until.to_s.should == expected.to_s
      end
    end

    describe "finders" do
      before do
        @session = Session.create(:verified => true)
      end

      it "finds nothing for a blank token" do
        Session.with_token(nil).should.be.nil
        Session.with_verification_token(nil).should.be.nil
      end

      it "finds a valid session based on a token" do
        Session.with_token(@session.token).should == @session
        Session.with_verification_token(@session.verification_token).should == @session
      end

      it "does not find an invalid session based on a token" do
        @session.update(:valid_until => 1.second.ago)
        Session.with_token(@session.token).should.be.nil
        Session.with_verification_token(@session.verification_token).should.be.nil
      end

      it "does not find a session with a wrong token" do
        Session.with_token('wrong').should.be.nil
        Session.with_verification_token('wrong').should.be.nil
      end

      it "does not find an unverified session" do
        @session.update(:verified => false)
        Session.with_token(@session.token).should.be.nil
      end

      it "finds an unverified session by verification token" do
        @session.update(:verified => false)
        Session.with_verification_token(@session.verification_token).should == @session
      end
    end

    it "coerces to YAML" do
      yaml = YAML.load(Session.new.to_yaml)
      yaml.keys.sort.should == %w(created_at token valid_until verified)
    end

    it "extends the validity" do
      session = Session.create
      session.update(:valid_until => 10.seconds.from_now, :verified => true)
      session.prolong!
      session.reload.valid_until.should > 10.seconds.from_now
    end

    it "does not extend the validity of an invalid session" do
      session = Session.create
      session.update(:valid_until => 10.seconds.ago, :verified => true)
      lambda { session.prolong! }.should.raise
      session = Session.create
      session.update(:valid_until => 10.seconds.from_now, :verified => false)
      lambda { session.prolong! }.should.raise
    end
  end
end
