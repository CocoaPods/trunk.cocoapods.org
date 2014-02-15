require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'
require 'app/concerns/git_commit_sha_validator'

module Pod
  module TrunkApp
    class PushJob
      attr_reader :pod_version, :committer, :specification_data, :commit_sha, :duration

      def initialize(pod_version, committer, specification_data)
        @pod_version, @committer, @specification_data = pod_version, comitter, specification_data
      end

      def pod_version_description
        "#{pod_version.pod.name} #{pod_version.name}"
      end

      def commit_message
        "[Add] #{pod_version_description}"
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
          @commit_sha = self.class.github.create_new_commit(pod_version.destination_path,
                                                            specification_data, # Re-add JSON.pretty_generate.
                                                            commit_message,
                                                            committer.name,
                                                            committer.email)
          log(:info, "has been pushed.")
        end
        true
      end

      protected

      def log(level, message, data = nil)
        # TODO add level and data to LogMessage
        #pod_version.add_log_message(:level => level, :message => "Push for `#{pod_version_description}' with temporary ID `#{object_id}' #{message}", :data => data)
        pod_version.add_log_message(:message => "Push for `#{pod_version_description}' with temporary ID `#{object_id}' #{message}")
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
        start = Time.now
        db.transaction(:savepoint => true, &block)
        return nil
      rescue Object => error
        return error
      ensure
        @duration = (Time.now - start).ceil
      end
    end
  end
end

