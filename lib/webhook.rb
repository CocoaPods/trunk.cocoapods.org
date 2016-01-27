require 'rest'

# A minimal web hook implementation.
#
# Usage:
#   Use Webhook.setup, then Webhook.call('type','action','message') in the server.
#
# Explanation:
# * The web hook spawns a child process where work is done.
# * The parent and child process are connected via a pipe.
# * The child will immediately wait for a message from the parent using select.
# * If Webhook.call('type','action','example message') is called, then
#   the child will read the message up to the first \n.
# * The child will then put together a curl call and execute it in another fork.
# * After forking the work, it will wait for the child to finish.
# * With the child finished and cleaned up, it will wait for the next
#   message from the parent (which might already have arrived).
#
class Webhook
  # API methods.
  #
  def self.pod_created=(targets)
    urls[:pod][:create] = targets
  end

  def self.pod_created(created_at, pod_name, version_name, commit_sha, data_url)
    call_convenience('pod', 'create', created_at, pod_name, version_name, commit_sha, data_url)
  end

  #
  def self.version_created=(targets)
    urls[:version][:create] = targets
  end

  def self.version_created(created_at, pod_name, version_name, commit_sha, data_url)
    call_convenience('version', 'create', created_at, pod_name, version_name, commit_sha, data_url)
  end

  #
  def self.spec_updated=(targets)
    urls[:spec][:update] = targets
  end

  def self.spec_updated(updated_at, pod_name, version_name, commit_sha, data_url)
    call_convenience('spec', 'update', updated_at, pod_name, version_name, commit_sha, data_url)
  end

  # URLs is a two-level self-initialising Hash structure.
  #
  # Contains levels { type => { action => [urls] } }.
  #
  def self.urls
    @urls ||= Hash.new { |h, k| h[k] = {} }
  end

  # Enable the Webhooks.
  #
  # Creates a pipe from parent to worker child.
  #
  def self.enable
    @parent, @child = IO.pipe
    start_child_process_thread
  end

  def self.enabled?
    !(@parent.nil? || @child.nil?)
  end

  # Disable the webhooks.
  #
  # Kill child, wait and remove.
  #
  def self.disable
    Process.kill 'KILL', @child_pid if @child_pid
  rescue Errno::ESRCH
    # Process wasn't there anymore, we don't need to kill it.
    'RuboCop: Do not suppress exceptions.'
  ensure
    Process.waitall
    dispose_child
    dispose_parent
  end

  def self.dispose_child
    if @child
      @child.close unless @child.closed?
      @child = nil
    end
  end

  def self.dispose_parent
    if @parent
      @parent.close unless @parent.closed?
      @parent = nil
    end
  end

  # Write the worker child.
  #
  # Important:
  # Messages can't contain newlines.
  #
  def self.call(type, action, message)
    return unless enabled?
    targets = urls[type.to_sym][action.to_sym]
    return if targets.empty?
    targets = targets.join(',').delete("\n")
    write_child "#{type};#{action};#{message.tr("\n", ' ')};#{targets}\n"
  end

  def self.write_child(message)
    @child.write message
  end

  def self.call_convenience(type, action, timestamp, pod_name, version_name, sha, data_url)
    hash = {
      :type => type,
      :action => action,
      :timestamp => timestamp,
      :pod => pod_name,
      :version => version_name,
      :commit => sha,
      :data_url => data_url,
    }
    call(type, action, hash.to_json)
  end

  # This runs a child process that listens to the master process.
  #
  def self.start_child_process_thread
    @child_pid = fork do
      loop do
        # Wait for input from the parent.
        #
        IO.select([@parent], nil) || next

        # Get all data up to the newline.
        #
        string = @parent.gets("\n").chomp
        type, action, message, targets = string.split(';', 4)
        targets = targets.split(',')

        # Send a message to all URLs.
        #
        # Spawn a worker, then wait for it to finish.
        #
        if message && !targets.empty?
          headers = { 'Content-Type' => 'application/json' }
          targets.each do |target|
            fork do
              REST.post(target, message, headers) do |http|
                http.open_timeout = 1
                http.read_timeout = 1
              end
            end
          end
          Process.waitall
        end
      end
    end
  end
end

# Before exiting, kill the worker child.
#
at_exit { Webhook.disable }
