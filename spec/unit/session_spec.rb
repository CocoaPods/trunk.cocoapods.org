require File.expand_path('../../spec_helper', __FILE__)

module Pod::PushApp
  describe "Session" do
    it "automatically creates a token for itself" do
      Session.new.token.length.should == 32
    end

    it "allows you to configure the token length" do
      session = Session.new(:token_length => 2)
      session.token.length.should == 2
    end
  end
end
