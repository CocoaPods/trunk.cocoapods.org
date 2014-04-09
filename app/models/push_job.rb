require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'

module Pod
  module TrunkApp
    class PushJob
      attr_reader :pod_version, :committer, :specification_data, :duration

      def initialize(pod_version, committer, specification_data)
        @pod_version, @committer, @specification_data = pod_version, committer, specification_data
      end

      def commit_message
        "[Add] #{pod_version.description}"
      end

      def push!
        log(:info, 'initiated', committer, specification_data)

        response, duration = measure_duration do
          self.class.github.create_new_commit(pod_version.destination_path,
                                              specification_data,
                                              commit_message,
                                              committer.name,
                                              committer.email)
        end

        if response.success?
          log(:info, "has been pushed (#{duration} s)")
        elsif response.failed_on_our_side?
          log(:error, "failed with HTTP error `#{response.status_code}' on our side (#{duration} s)", committer, response.body)
        elsif response.failed_on_their_side?
          log(:warning, "failed with HTTP error `#{response.status_code}' on GitHub’s side (#{duration} s)", committer, response.body)
        elsif response.failed_due_to_timeout?
          log(:warning, "failed due to timeout (#{duration} s)", committer, response.timeout_error)
        end

        return response

      rescue Object => error
        log(:error, "failed with error: #{error.message}.", committer, error.backtrace.join("\n\t\t"))
        raise
      end

      protected

      def log(level, message, committer = nil, data = nil)
        pod_version.add_log_message(
          reference: "PushJob with temporary ID: #{object_id}",
          level: level,
          message: "Push for `#{pod_version.description}' #{message}.",
          owner: committer,
          data: data
        )
      end

      def measure_duration
        start_time = Time.now
        result = yield
        [result, Time.now - start_time]
      end

      def self.github
        @github ||= GitHub.new(ENV['GH_REPO'], username: ENV['GH_TOKEN'], password: 'x-oauth-basic')
      end
    end
  end
end
