require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'

module Pod
  module TrunkApp
    class SubmissionJob < Sequel::Model
      class TaskError < ::StandardError; end

      RETRY_COUNT = 6

      self.dataset = :submission_jobs
      plugin :timestamps

      many_to_one :pod_version
      many_to_one :owner
      one_to_many :log_messages, :order => Sequel.asc(:created_at)

      def self.disable_info_logging
        return yield if ENV['RACK_ENV'] == 'development'
        sev_threshold = TRUNK_APP_LOGGER.sev_threshold
        TRUNK_APP_LOGGER.sev_threshold = Logger::WARN
        yield
      ensure
        TRUNK_APP_LOGGER.sev_threshold = sev_threshold
      end

      def self.find_first_job_in_queue
        disable_info_logging do
          for_update.order(Sequel.asc(:updated_at)).first(:needs_to_perform_work => true)
        end
      end

      def self.perform_task!
        if job = find_first_job_in_queue
          job.perform_next_task!
          true
        else
          false
        end
      end

      def after_create
        super
        add_log_message(:message => 'Submitted.')
      end

      def after_update
        super
        case @columns_updated[:succeeded]
        when true
          pod_version.update(:published => true, :published_by_submission_job => self)
          add_log_message(:message => 'Published.')
        when false
          add_log_message(:message => 'Failed.')
        end
      end

      alias_method :needs_to_perform_work?, :needs_to_perform_work

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

      def attempts=(count)
        super
        if count >= RETRY_COUNT
          self.succeeded = false
          self.needs_to_perform_work = false
        end
      end

      def pull_request_number=(number)
        super
        self.needs_to_perform_work = pull_request_number.nil?
      end

      def merge_commit_sha=(sha)
        super
        self.succeeded = true unless merge_commit_sha.nil?
      end

      def perform_next_task!
        unless needs_to_perform_work?
          raise TaskError, "This job is marked as not needing to perform work."
        end

        self.class.tasks.each do |options|
          if needs_to_perform_task?(options)
            send(options[:method])
            return
          end
        end

        raise TaskError, "Unable to determine job state."
      end

      def tasks_completed
        count = 0
        self.class.tasks.each do |options|
          return count unless has_performed_task?(options)
          count += 1
        end
        count
      end

      protected

      def needs_value?(attribute)
        send(attribute).nil?
      end

      def needs_to_perform_task?(options)
        options[:if] ? send(options[:if]) : needs_value?(options[:name])
      end

      def has_performed_task?(options)
        !needs_value?(options[:name])
      end

      def self.perform_task(&block)
        db.transaction(:savepoint => true, &block)
        return nil
      rescue Object => error
        TRUNK_APP_LOGGER.error "#{error.message}\n\t\t#{error.backtrace.join("\n\t\t")}"
        return error
      end

      def perform_task(message, &block)
        add_log_message(:message => message)
        if error = self.class.perform_task(&block)
          update(:attempts => attempts + 1)
          # TODO report full error to error reporting service
          add_log_message(:message => "Error: #{error.message}")
        end
      end

      # GitHub pull-request
      #
      # TODO validate SHAs

      REPO        = ENV['GH_REPO'].dup.freeze
      BASE_BRANCH = 'master'.freeze
      BASIC_AUTH  = { :username => ENV['GH_USERNAME'], :password => ENV['GH_PASSWORD'] }.freeze

      def github
        @github ||= GitHub.new(REPO, BASE_BRANCH, BASIC_AUTH)
      end

      # Tasks state machine

      def self.tasks
        @tasks ||= []
      end

      def self.task(name, opts = {}, &block)
        method = "perform_task_#{name}!"
        opts[:name] = name
        opts[:method] = method
        tasks << opts
        define_method(method, &block)
      end

      task :base_commit_sha do
        perform_task "Fetching latest commit SHA." do
          update(:base_commit_sha => github.fetch_latest_commit_sha)
        end
      end

      task :base_tree_sha do
        perform_task "Fetching tree SHA of commit #{base_commit_sha}." do
          update(:base_tree_sha => github.fetch_base_tree_sha(base_commit_sha))
        end
      end

      task :new_tree_sha do
        perform_task "Creating new tree based on tree #{base_tree_sha}." do
          destination_path = File.join(pod_version.pod.name, pod_version.name, "#{pod_version.pod.name}.podspec.yaml")
          update(:new_tree_sha => github.create_new_tree(base_tree_sha,
                                                         destination_path,
                                                         specification_data))
        end
      end

      task :new_commit_sha do
        perform_task "Creating new commit with tree #{new_tree_sha}." do
          # TODO get this from the user that pushed the spec.
          message = "[Add] #{pod_version.pod.name} #{pod_version.name}"
          update(:new_commit_sha => github.create_new_commit(new_tree_sha,
                                                             base_commit_sha,
                                                             message,
                                                             owner.name,
                                                             owner.email))
        end
      end

      # TODO create branch name according to: https://www.kernel.org/pub/software/scm/git/docs/git-check-ref-format.html
      task :new_branch_ref do
        branch_name = "#{pod_version.pod.name}-#{pod_version.name}-job-#{self.id}"
        perform_task "Creating new branch `#{branch_name}' with commit #{new_commit_sha}." do
          update(:new_branch_ref => github.create_new_branch(branch_name,
                                                             new_commit_sha))
        end
      end

      task :pull_request_number do
        perform_task "Creating new pull-request with branch #{new_branch_ref}." do
          title = "[Add] #{pod_version.pod.name} #{pod_version.name}"
          update(:pull_request_number => github.create_new_pull_request(title,
                                                                        pod_version.url,
                                                                        new_branch_ref))
        end
      end

      def should_perform_merge?
        needs_value?(:merge_commit_sha)
      end

      task :merge_commit_sha, :if => :should_perform_merge? do
        perform_task "Merging pull-request number #{pull_request_number}." do
          update(:merge_commit_sha => github.merge_pull_request(pull_request_number))
        end
      end

      task :deleted_branch do
        perform_task "Deleting branch `#{new_branch_ref}'." do
          github.delete_branch(new_branch_ref)
          update(:deleted_branch => true, :needs_to_perform_work => false)
        end
      end
    end
  end
end

