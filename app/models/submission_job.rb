require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'
require 'app/concerns/git_commit_sha_validator'

module Pod
  module TrunkApp
    class SubmissionJob < Sequel::Model
      include Concerns::GitCommitSHAValidator

      self.dataset = :submission_jobs

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :pod_version
      many_to_one :owner
      one_to_many :log_messages, :order => Sequel.asc(:created_at)

      def in_progress?
        succeeded.nil?
      end

      def completed?
        !succeeded.nil? && succeeded
      end

      def failed?
        !succeeded.nil? && !succeeded
      end

      def duration
        ((in_progress? ? Time.now : updated_at) - created_at).ceil
      end

      def submit_specification_data!
        perform_work 'Submitting specification data to GitHub' do
          message = "[Add] #{pod_version.pod.name} #{pod_version.name}"
          commit_sha =  self.class.github.create_new_commit(pod_version.destination_path,
                                                            specification_data,
                                                            message,
                                                            owner.name,
                                                            owner.email)
          update(:commit_sha => commit_sha, :succeeded => true)
          pod_version.update(:published => true, :published_by_submission_job => self, :commit_sha => commit_sha)
          pod_version.pod.add_owner(owner) if pod_version.pod.owners.empty?
          add_log_message(:message => 'Published.')
        end
      end

      protected

      def validate
        super
        validates_presence :pod_version_id
        validates_presence :owner_id
        validates_presence :specification_data
        validates_git_commit_sha :commit_sha
      end

      def self.github
        @github ||= GitHub.new(ENV['GH_REPO'], :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic')
      end

      def self.perform_work(&block)
        db.transaction(:savepoint => true, &block)
        return nil
      rescue Object => error
        TRUNK_APP_LOGGER.error "#{error.message}\n\t\t#{error.backtrace.join("\n\t\t")}"
        return error
      end

      def perform_work(message, &block)
        add_log_message(:message => message)
        if error = self.class.perform_work(&block)
          update(:succeeded => false)
          add_log_message(:message => "Failed with error: #{error.message}")
          raise error
        end
      end
    end
  end
end

