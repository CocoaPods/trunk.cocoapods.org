require File.expand_path('../../spec_helper', __FILE__)

require 'token'

describe 'Token' do
  it 'generates a token' do
    Token.generate { false }.length.should == 32
  end

  it 'generates a token with a different size' do
    [8, 16, 32, 64].each do |length|
      Token.generate(length) { false }.length.should == length
    end
  end

  it 'does not generate the same token twice (in general)' do
    10.times do
      Token.generate { false }.should.not == Token.generate { false }
    end
  end

  it 'yields a new token in case a collision occurs' do
    tokens = []
    Token.generate do |token|
      tokens << token
      tokens.size < 3
    end
    tokens.uniq.size.should == 3
  end

  it 'raises an exception if for whatever reason more than 10 collisions occur' do
    count = 0
    should.raise Token::CollisionError do
      Token.generate do
        count += 1
        true
      end
    end
    count.should == 10
  end
end
