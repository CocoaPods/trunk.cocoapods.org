require File.expand_path('../../spec_helper', __FILE__)

require 'webhook'

describe 'Webhook' do

  it 'does only block for a very short time' do
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

    # verify expectation.
    #
    duration.should < 0.01
  end

end
