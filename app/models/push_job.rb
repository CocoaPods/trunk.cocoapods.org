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
        log(:info, "initiated by: #{committer.name} <#{committer.email}>.", specification_data)
        response = self.class.github.create_new_commit(pod_version.destination_path,
                                                       specification_data,
                                                       commit_message,
                                                       committer.name,
                                                       committer.email)
        case response.status_code
        when 200...400
          commit_sha = response.commit_sha
          log(:info, "has been pushed.")
          return commit_sha
        when 400...500
          log(:error, "failed with HTTP error `#{response.status_code}' on our side.")
        when 500...600
          log(:warning, "failed with HTTP error `#{response.status_code}' on GitHub’s side.")
        else
          raise "Unexpected HTTP response: #{response.inspect}"
        end
        nil
      rescue Object => error
        log(:error, "failed with error: #{error.message}.", error.backtrace.join("\n\t\t"))
        raise
      end

      protected

      def log(level, message, data = nil)
        # TODO add data to LogMessage
        #
        pod_version.add_log_message(:level => level, :message => "Push for `#{pod_version.description}' with temporary ID `#{object_id}' #{message}") # :data => data
      end

      def self.github
        @github ||= GitHub.new(ENV['GH_REPO'], :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic')
      end
    end
  end
end

