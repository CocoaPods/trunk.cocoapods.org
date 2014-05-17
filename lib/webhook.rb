# A minimal web hook implementation.
#
# Use Webhook.call("message") in the server.
# Use Webhook.run in a worker process.
#
# Note that Webhook.call will currently block if there is no worker process.
#
class Webhook
  class << self
    attr_writer :urls

    # By default, we have no services to ping.
    #
    def urls
      @urls || []
    end
  end

  # Fifo file directory
  #
  def self.directory
    File.expand_path('./tmp')
  end

  # Set up FIFO file (the "queue").
  #
  def self.setup
    Dir.mkdir(directory) unless File.exist?(directory)
    `mkfifo #{fifo}` unless File.exist?(fifo)
  end

  # Fifo file location.
  #
  def self.fifo
    @fifo ||= "#{directory}/webhook_calls"
  end

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
      message = `cat #{fifo} 2>/dev/null`

      # Check if it was an actual message.
      # Empty if it's not.
      #
      next if message == ''

      # Remove \n from message.
      #
      message.chomp!

      # Clean up old zombie children as soon as our queue is larger than 10.
      #
      Process.wait2(pids.shift, Process::WNOHANG) if pids.size > 10

      # Contact webhooks in a child process.
      #
      if urls && !urls.empty?
        encoded_message = URI.encode(message)
        command = %Q(curl -X POST -sfGL --data "message=#{encoded_message}" --connect-timeout 1 --max-time 1 {#{urls.join(',')}})
        pids << fork { exec command }
      end
    end
  end

  def self.clean
    `rm #{fifo}` if File.exist?(fifo)
  end
end

at_exit { Webhook.clean }
