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

      def succeeded=(status)
        super
        self.needs_to_perform_work = false unless status.nil?
      end

      def attempts=(count)
        super
        self.succeeded = false if count >= RETRY_COUNT
      end

      def new_commit_url=(url)
        super
        self.succeeded = true unless new_commit_url.nil?
      end

      def perform_next_task!
        unless needs_to_perform_work?
          raise TaskError, "This job is marked as not needing to perform work."
        end

        self.class.tasks.each do |name|
          if needs_value?(name)
            send(TASK_NAME_TEMPLATE % name)
            return
          end
        end

        raise TaskError, "Unable to determine job state."
      end

      def tasks_completed
        count = 0
        self.class.tasks.each do |name|
          return count if needs_value?(name)
          count += 1
        end
        count
      end

      protected

      def needs_value?(attribute)
        send(attribute).nil?
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

      TASK_NAME_TEMPLATE = 'perform_task_%s!'

      def self.tasks
        @tasks ||= []
      end

      def self.task(name, &block)
        tasks << name
        define_method(TASK_NAME_TEMPLATE % name, &block)
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
          message = "[Add] #{pod_version.pod.name} #{pod_version.name}"
          update(:new_commit_sha => github.create_new_commit(new_tree_sha,
                                                             base_commit_sha,
                                                             message,
                                                             owner.name,
                                                             owner.email))
        end
      end

      task :new_commit_url do
        perform_task "Adding commit to master branch #{new_commit_sha}." do
          update(:new_commit_url => github.add_commit_to_branch(new_commit_sha, 'master'))
        end
      end
    end
  end
end

