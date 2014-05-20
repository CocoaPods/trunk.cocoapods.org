require File.expand_path('../../spec_helper', __FILE__)

require 'webhook'

describe 'Webhook' do

  it 'does not take long to send a message' do
    Webhook.urls = []

    # Measure time waiting for webhook (blocks).
    #
    t = Time.now
    Webhook.call('testing')
    duration = Time.now - t

    duration.should < 0.01
  end

  it 'sets enabled? correctly' do
    Webhook.urls = ['hello']
    Webhook.enabled?.should == true

    Webhook.urls = []
    Webhook.enabled?.should == false
  end

end
