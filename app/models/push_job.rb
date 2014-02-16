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
        perform_work do
          # TODO Make the GitHub class return the real response object *and* the extracted data. Possibly just monkey-patch REST::Response?
          # E.g.
          #
          #   response = self.class.github.create_new_commit(...)
          #   if response.success?
          #     @commit_sha = response.extracted_value
          #   else
          #     log(:error, "failed with HTTP status: #{response}")
          #   end
          #
          commit_sha = self.class.github.create_new_commit(pod_version.destination_path,
                                                           specification_data, # Re-add JSON.pretty_generate.
                                                           commit_message,
                                                           committer.name,
                                                           committer.email)
          log(:info, "has been pushed.")
          return commit_sha
        end
        nil
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

      def perform_work(&block)
        if error = perform_work_and_rescue(&block)
          log(:error, "failed with error: #{error.message}.", error.backtrace.join("\n\t\t"))
          raise error
        end
      end

      def perform_work_and_rescue(&block)
        block.call
        return nil
      rescue Object => error
        return error
      end
    end
  end
end

