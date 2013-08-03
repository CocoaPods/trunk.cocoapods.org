require 'app/models/pod_version'
require 'app/models/log_message'

module Pod
  module PushApp
    class SubmissionJob < Sequel::Model
      self.dataset = :submission_jobs
      plugin :timestamps

      many_to_one :pod_version
      one_to_many :log_messages

      def after_create
        super
        add_log_message(:message => 'Submitted')
      end

      def pull_request_number=(number)
        super
        self.state = 'pull-request-submitted' unless pull_request_number.nil?
      end

      def travis_build_success=(result)
        super
        unless travis_build_success.nil?
          self.state = travis_build_success ? 'travis-notification-received' : 'failed'
        end
      end

      def merge_commit_sha=(sha)
        super
        self.state = 'completed' unless merge_commit_sha.nil?
      end

      def pull_request_submitted?
        state == 'pull-request-submitted'
      end

      def travis_notification_received?
        state == 'travis-notification-received'
      end

      alias_method :travis_build_success?, :travis_build_success

      def failed?
        state == 'failed'
      end

      def completed?
        state == 'completed'
      end

      def perform_next_pull_request_task!
        if base_commit_sha.nil?
          fetch_base_commit_sha!
        elsif base_tree_sha.nil?
          fetch_base_tree_sha!
        elsif new_tree_sha.nil?
          create_tree!
        elsif new_commit_sha.nil?
          create_commit!
        elsif new_branch_ref.nil?
          create_branch!
        elsif pull_request_number.nil?
          create_pull_request!
        else
          raise 'No more pull-request tasks to perform.'
        end
      end

      def merge_pull_request!
        add_log_message(:message => "Merging pull-request number #{pull_request_number}")
        update(:merge_commit_sha => github.merge_pull_request(pull_request_number))
      end

      protected

      # GitHub pull-request
      #
      # TODO validate SHAs

      REPO        = ENV['GH_REPO'].dup.freeze
      BASE_BRANCH = 'master'.freeze
      BASIC_AUTH  = { :username => ENV['GH_USERNAME'], :password => ENV['GH_PASSWORD'] }.freeze

      def github
        @github ||= GitHub.new(REPO, BASE_BRANCH, BASIC_AUTH)
      end

      def fetch_base_commit_sha!
        add_log_message(:message => "Fetching latest commit SHA.")
        update(:base_commit_sha => github.fetch_latest_commit_sha)
      end

      def fetch_base_tree_sha!
        add_log_message(:message => "Fetching tree SHA of commit #{base_commit_sha}.")
        update(:base_tree_sha => github.fetch_base_tree_sha)
      end

      def create_tree!
        add_log_message(:message => "Creating new tree based on tree #{base_tree_sha}.")
        destination_path = File.join(pod_version.pod.name, pod_version.name, "#{pod_version.pod.name}.podspec")
        update(:new_tree_sha => github.create_new_tree(base_tree_sha,
                                                       destination_path,
                                                       specification_data))
      end

      def create_commit!
        add_log_message(:message => "Creating new commit with tree #{new_tree_sha}.")
        message = "[Add] #{pod_version.pod.name} #{pod_version.name}"
        update(:new_commit_sha => github.create_new_commit(new_tree_sha,
                                                           base_commit_sha,
                                                           message))
      end

      # TODO create branch name according to: https://www.kernel.org/pub/software/scm/git/docs/git-check-ref-format.html
      def create_branch!
        branch_name = "#{pod_version.pod.name}-#{pod_version.name}"
        add_log_message(:message => "Creating new branch `#{branch_name}' with commit #{new_commit_sha}.")
        update(:new_branch_ref => github.create_new_branch(branch_name,
                                                           new_commit_sha))
      end

      def create_pull_request!
        add_log_message(:message => "Creating new pull-request with branch #{new_branch_ref}.")
        title = "[Add] #{pod_version.pod.name} #{pod_version.name}"
        update(:pull_request_number => github.create_new_pull_request(title,
                                                                      pod_version.url,
                                                                      new_branch_ref))
      end
    end
  end
end

