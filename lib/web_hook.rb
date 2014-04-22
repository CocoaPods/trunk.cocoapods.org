# A minimal web hook implementation.
#
# Use WebHook.call("message") in the server.
# Use WebHook.run in a worker process.
#
# Note that WebHook.call will currently block if there is no worker process.
#
class WebHook
  # List of attached web hook URLs.
  #
  URLS = [
    "http://metrics.cocoapods.org/hooks/trunk/#{ENV['OUTGOING_HOOK_PATH']}"
  ]

  # Fifo file location.
  #
  def self.fifo
    './tmp/web_hook_calls'
  end

  # Set up FIFO file (the "queue").
  #
  `mkfifo #{fifo}` unless File.exist?(fifo)

  # Use in Trunk to notify all attached services.
  #
  # Note: Blocks until message is read.
  #
  def self.call(message)
    `echo #{message} > #{fifo}`
  end

  # Used in the worker process to process hook calls.
  #
  # Reads from
  #
  def self.run
    loop do

      # Block and wait for messages.
      #
      message = `cat #{fifo}`

      # Contact web hooks in a child process.
      #
      fork do
        URLS.each do |url|
          `curl #{url} -d"#{message}" --max-time 1`
        end
      end

    end
  end
end
