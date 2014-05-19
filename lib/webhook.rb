# A minimal web hook implementation.
#
# Use Webhook.setup, then Webhook.call("message") in the server.
#
class Webhook
  class << self
    attr_reader :urls
  end

  # Create a pipe from parent to worker child.
  #
  def self.setup(*urls)
    @parent, @child = IO.pipe
    self.urls = urls
  end

  def self.urls=(urls)
    @urls = urls
    cleanup
    start_child_process_thread
  end

  # Kill child, wait and remove.
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
        IO.select([@parent], nil) || next

        # Get all data up to the newline.
        #
        message = @parent.gets("\n").chomp

        # Send a message to all URLs.
        #
        # Spawn a worker, then wait for it to finish.
        #
        if message
          encoded_message = URI.encode(message)
          cmd = %Q(curl -X POST -sfGL --data "message=#{encoded_message}" --connect-timeout 1 --max-time 1 {#{urls.join(',')}})
          fork { exec cmd }
          Process.waitall
        end
      end
    end
  end

  # Write the worker child.
  #
  # Important:
  # Messages can't contain newlines.
  # If they do, they will be replaced by a single space.
  #
  def self.call(message)
    @child.write "#{message.gsub("\n", ' ')}\n"
  end
end

at_exit { Webhook.cleanup }
