require File.expand_path('../../spec_helper', __FILE__)

require 'webhook'

describe 'Webhook' do

  it 'does only block for a short time' do
    # Set up webhook directory.
    #
    Webhook.directory = '.'

    # Run webhooks in a child.
    #
    pid = fork do
      Webhook.run
    end

    # Measure time waiting for webhook (blocks).
    #
    t = Time.now
    Webhook.call('testing')
    duration = Time.now - t

    # Kill the child process.
    #
    Process.kill 'KILL', pid

    # Collect the remains.
    #
    Process.waitall

    # Verify expectation.
    #
    # Usually below 0.004, but set to 0.5 for Travis.
    #
    duration.should < 0.5
  end

end
