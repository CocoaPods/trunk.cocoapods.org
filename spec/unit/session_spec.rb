require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "Session" do
    describe "when initializing" do
      it "automatically creates a token for itself" do
        Session.new.token.length.should == 32
      end

      it "allows you to configure the token length" do
        session = Session.new(:token_length => 2)
        session.token.length.should == 2
      end

      it "has a default validity time" do
        Session.new.valid_for.should == 128
      end

      it "sets a default expiration date" do
        expected = Time.now + Session.new.valid_for * 3600 * 24
        Session.new.valid_until.to_s.should == expected.to_s
      end

      it "allows you to set a different validity time" do
        Session.new(:valid_for => 7).valid_for.should == 7
      end

      it "sets a default expiration date based on the validity time" do
        valid_for = 23
        expected = Time.now + valid_for * 3600 * 24
        Session.new(:valid_for => valid_for).valid_until.to_s.should == expected.to_s
      end
    end

    describe "finders" do
      it "finds nothing for a blank token" do
        Session.with_token(nil).should.be.nil
      end

      it "finds a valid session based on a token" do
        session = Session.create
        Session.with_token(session.token).should == session
      end

      it "does not find an invalid session based on a token" do
        session = Session.create(:valid_until => Time.now - 240)
        Session.with_token(session.token).should == session
      end

      it "does not find a session with a wrong token" do
        Session.create
        Session.with_token('wrong').should.be.nil
      end
    end
  end
end
