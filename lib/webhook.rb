# A minimal web hook implementation.
#
# Use Webhook.call("message") in the server.
# Use Webhook.run in a worker process.
#
# Note that Webhook.call will currently block if there is no worker process.
#
class Webhook
  # List of attached web hook URLs.
  #
  # Warning: Do not add non-existing domains.
  #
  garbled_hook_path = ENV['OUTGOING_HOOK_PATH']
  URLS = [
    "http://cocoadocs.org/hooks/trunk/#{garbled_hook_path}",
    # "http://metrics.cocoapods.org/hooks/trunk/#{garbled_hook_path}",
    "http://search.cocoapods.org/hooks/trunk/#{garbled_hook_path}"
  ]

  class << self
    attr_writer :directory
  end
  def self.directory
    @directory || './tmp'
  end

  # Fifo file location.
  #
  def self.fifo
    "#{directory}/webhook_calls"
  end

  # Set up FIFO file (the "queue").
  #
  `mkfifo #{fifo}` unless File.exist?(fifo)

  # Use in Trunk to notify all attached services.
  #
  # Blocks until message is read.
  # With the below implementation, blocks on average 0.004 s
  # if this method is called 10 times per second on average.
  #
  def self.call(message)
    `echo #{message} > #{fifo}`
  end

  # Used in the worker process to process hook calls.
  #
  # Reads from the fifo queue.
  #
  # This absolutely needs to run in the current design,
  # as the self.call above will block on fifo until it's read.
  #
  def self.run
    # Remember zombie children.
    #
    pids = []
    loop do
      # Block and wait for messages.
      #
      message = `cat #{fifo}`.chomp

      # Clean up old zombie children as soon as our queue is larger than 10.
      #
      Process.wait2(pids.shift, Process::WNOHANG) if pids.size > 10

      # Contact webhooks in a child process.
      #
      encoded_message = URI.encode(message)
      command = %Q(curl -X POST -vGL --data "message=#{encoded_message}" --connect-timeout 1 --max-time 1 {#{URLS.join(',')}})
      pids << fork { exec command }
    end
  end

  def self.clean
    `rm #{fifo}` if File.exist?(fifo)
  end
end

at_exit { Webhook.clean }
