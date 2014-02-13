require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'
require 'app/concerns/git_commit_sha_validator'

module Pod
  module TrunkApp
    class PushJob < Sequel::Model
      self.dataset = :push_jobs

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :commit
      many_to_one :owner
      one_to_many :log_messages, :order => Sequel.asc(:created_at)

      def self.succeeded
        commit_dataset.where(:pushed => true) # TODO
      end
      
      def self.failed
        commit_dataset.where(:pushed => false) # TODO
      end
      
      def self.in_progress
        commit_dataset.where(:pushed => nil) # TODO
      end
    
      def in_progress?
        succeeded.nil?
      end
      
      def completed?
        !succeeded.nil? && succeeded
      end

      def failed?
        !succeeded.nil? && !succeeded
      end
      
      def succeeded
        commit && commit.succeeded
      end
      
      def duration
        ((in_progress? ? Time.now : updated_at) - created_at).ceil
      end
      
      def commit_sha
        commit.sha
      end
      
      def pod_version
        commit.pod_version
      end
      
      def specification_data
        commit.specification_data
      end

      # TODO Refactor this whole method. Especially how pod_version is needed.
      #
      def push!
        perform_work 'Submitting specification data to GitHub' do
          commit_sha = self.class.github.create_new_commit(pod_version.destination_path,
                                                           specification_data, # Re-add JSON.pretty_generate.
                                                           pod_version.message,
                                                           owner.name,
                                                           owner.email)
          commit.update(:pushed => true, :sha => commit_sha)
          pod_version.pod.add_owner(owner) if pod_version.pod.owners.empty?
          add_log_message(:message => 'Published.')
        end
      end

      protected

      def validate
        super
        validates_presence :owner_id
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
          commit.update(:pushed => false)
          add_log_message(:message => "Failed with error: #{error.message}")
          raise error
        end
      end
    end
  end
end
