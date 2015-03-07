require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'

module Pod
  module TrunkApp
    class PushJob
      attr_reader :pod_version, :committer, :specification_data, :job_type, :duration

      def initialize(pod_version, committer, specification_data, job_type)
        @pod_version, @committer, @specification_data, @job_type = pod_version, committer, specification_data, job_type
      end

      def commit_message
        "[#{job_type}] #{pod_version.description}"
      end

      def push!
        log(:info, 'initiated', committer, specification_data)

        response, duration = measure_duration do
          self.class.github.create_new_commit(
            pod_version.destination_path,
            specification_data,
            commit_message,
            committer.name,
            committer.email
          )
        end

        log_response(response, committer, duration)
        return response

      rescue Object => error
        message = "failed with error: #{error.message}."
        log(:error, message, committer, error.backtrace.join("\n\t\t"))
        raise
      end

      protected

      def log_response(response, committer, duration)
        if response.success?
          log(:info, "has been pushed (#{duration} s)")
        elsif response.failed_on_our_side?
          message = "failed with HTTP error `#{response.status_code}' on " \
            "our side (#{duration} s)"
          log(:error, message, committer, response.body)
        elsif response.failed_on_their_side?
          message = "failed with HTTP error `#{response.status_code}' on " \
            "GitHub’s side (#{duration} s)"
          log(:warning, message, committer, response.body)
        elsif response.failed_due_to_timeout?
          message = "failed due to timeout (#{duration} s)"
          log(:warning, message, committer, response.timeout_error)
        end
      end

      def log(level, message, committer = nil, data = nil)
        pod_version.add_log_message(
          :reference => "PushJob with temporary ID: #{object_id}",
          :level => level,
          :message => "Push for `#{pod_version.description}' #{message}.",
          :owner => committer,
          :data => data
        )
      end

      def measure_duration
        start_time = Time.now
        result = yield
        [result, Time.now - start_time]
      end

      def self.github
        @github ||= GitHub.new(
          ENV['GH_REPO'],
          :username => ENV['GH_TOKEN'],
          :password => 'x-oauth-basic'
        )
      end
    end
  end
end
