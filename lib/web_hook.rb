class WebHook

  # List of attached web hook URLs.
  #
  URLs = [
    "http://metrics.cocoapods.org/hooks/trunk/#{ENV['OUTGOING_HOOK_PATH']}"
  ]

  # Fifo file location.
  #
  def self.fifo
    './tmp/web_hook_calls'
  end

  # Set up FIFO file (the "queue").
  #
  `mkfifo #{fifo}`

  # Use in Trunk to notify all attached services.
  #
  # Note: Blocks.
  #
  def self.call message
    `#{message} > #{fifo}`
  end

  # Used in the worker process to process hook calls.
  #
  # Reads from
  #
  def self.run
    while do
      message = `cat #{fifo}`
      URLs.each do |url|
        `curl #{url} -d"#{message}" --max-time 1`
      end
    end
  end

end
