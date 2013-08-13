require File.expand_path('../../spec_helper', __FILE__)

require 'token'

describe "Token" do
  it "generates a token" do
    Token.generate.length.should == Token::DEFAULT_LENGTH
  end

  it "does not generate the same token twice (in general)" do
    10.times do
      Token.generate.should.not == Token.generate
    end
  end

  it "generates a token with a different size" do
    [2, 3, 5, 10].each do |length|
      Token.generate(:length => length).length.should == length
    end
  end
end