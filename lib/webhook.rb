# A minimal web hook implementation.
#
# Usage:
#   Use Webhook.setup, then Webhook.call("message") in the server.
#
# Explanation:
# * The web hook spawns a child process where work is done.
# * The parent and child process are connected via a pipe.
# * The child will immediately wait for a message from the parent using select.
# * If Webhook.call('example message') is called, then
#   the child will read the message up to the first \n.
# * The child will then put together a curl call and execute it in another fork.
# * After forking the work, it will wait for the child to finish.
# * With the child finished and cleaned up, it will wait for the next
#   message from the parent (which might already have arrived).
#
class Webhook
  class << self
    attr_reader :urls
  end

  # Setup the Webhooks. Needs to be called once.
  #
  # Creates a pipe from parent to worker child.
  #
  def self.setup(*urls)
    @parent, @child = IO.pipe
    self.urls = urls
  end

  # Set the URLs the Webhook service should be using.
  #
  # This will stop the old worker process,
  # and restart a new one using the new URLs.
  #
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
        if message && !urls.empty?
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

# Before exiting, kill the worker child.
#
at_exit { Webhook.cleanup }
