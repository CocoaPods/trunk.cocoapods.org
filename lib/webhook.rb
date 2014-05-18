# A minimal web hook implementation.
#
# Use Webhook.setup, then Webhook.call("message") in the server.
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
    # For testing purposes.
    #
    'http://requestb.in/1d8wrju1'

    # "http://cocoadocs.org/hooks/trunk/#{garbled_hook_path}",
    # "http://metrics.cocoapods.org/hooks/trunk/#{garbled_hook_path}",
    # "http://search.cocoapods.org/hooks/trunk/#{garbled_hook_path}"
  ]

  # Create a pipe from parent to worker child.
  #
  def self.setup
    @parent, @child = IO.pipe
    start_child_process_thread
  end

  #
  #
  def self.cleanup
    Process.kill 'KILL', @child_pid if @child_pid
    Process.waitall
  end

  # This runs a thread that listens to the master process.
  #
  def self.start_child_process_thread
    @child_pid = fork do
      loop do
        # Wait for input from the child.
        #
        IO.select([@parent], nil) or next

        # Get all data up to the newline.
        #
        message = @parent.gets("\n").chomp

        # Send a message to all URLs.
        #
        if message
          encoded_message = URI.encode(message)
          command = %Q(curl -X POST -sfGL --data "message=#{encoded_message}" --connect-timeout 1 --max-time 1 {#{URLS.join(',')}})
          fork { exec command }
          Process.waitall
        end
      end
    end
  end

  # Write the worker child.
  #
  def self.call message
    @child.write "#{message}\n"
  end
end

at_exit { Webhook.cleanup }
