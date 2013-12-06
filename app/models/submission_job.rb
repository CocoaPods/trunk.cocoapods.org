require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'

module Pod
  module TrunkApp
    class SubmissionJob < Sequel::Model
      self.dataset = :submission_jobs
      plugin :timestamps

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
          update(:succeeded => true, :commit_sha => commit_sha, :succeeded => true)
          pod_version.update(:published => true, :published_by_submission_job => self, :commit_sha => commit_sha)
          add_log_message(:message => 'Published.')
        end
      end

      protected

      REPO       = ENV['GH_REPO'].dup.freeze
      BASIC_AUTH = { :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic' }.freeze

      def self.github
        @github ||= GitHub.new(REPO, BASIC_AUTH)
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
          # TODO report full error to error reporting service
          add_log_message(:message => "Failed with error: #{error.message}")
          false
        else
          true
        end
      end
    end
  end
end

