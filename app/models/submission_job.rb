require 'app/models/github'
require 'app/models/log_message'
require 'app/models/pod'
require 'app/models/pod_version'

module Pod
  module TrunkApp
    class SubmissionJob < Sequel::Model
      class TaskError < ::StandardError; end

      RETRY_COUNT = 10
      TRAVIS_BUILD_STATUS_TIMEOUT = -10.minutes

      self.dataset = :submission_jobs
      plugin :timestamps

      many_to_one :pod_version
      one_to_many :log_messages

      def self.disable_info_logging
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

      def self.find_jobs_in_queue_that_need_travis_build_status_updates
        for_update.where(:succeeded => nil, :travis_build_success => nil)
                  .where('updated_at < ?', TRAVIS_BUILD_STATUS_TIMEOUT.from_now)
                  .exclude(:pull_request_number => nil)
      end

      def self.update_travis_build_statuses!
        TRUNK_APP_LOGGER.info('--- Updating Travis build statuses ---')
        jobs = find_jobs_in_queue_that_need_travis_build_status_updates.to_a
        return if jobs.empty?
        TRUNK_APP_LOGGER.info("[!] There are a total of #{jobs.size} jobs in the queue that have not received a notification from Travis yet.")

        Travis.pull_requests do |travis|
          jobs.delete_if do |job|
            if job.pull_request_number == travis.pull_request_number
              job.update_travis_build_status(travis)
              TRUNK_APP_LOGGER.info(job.inspect)
              true
            else
              false
            end
          end
          if jobs.empty?
            TRUNK_APP_LOGGER.info('--- Done updating Travis build statuses ---')
            break
          end
        end
      end

      def after_create
        super
        add_log_message(:message => 'Submitted')
      end

      def after_update
        super
        if @columns_updated.has_key?(:succeeded) && @columns_updated[:succeeded] == true
          pod_version.update(:published => true)
          add_log_message(:message => 'Published')
        end
      end

      alias_method :travis_build_success?, :travis_build_success
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

      def pull_request_number=(number)
        super
        self.needs_to_perform_work = pull_request_number.nil?
      end

      def travis_build_success=(result)
        super
        unless travis_build_success.nil?
          self.needs_to_perform_work = travis_build_success?
          self.succeeded = false unless travis_build_success?
        end
      end

      def merge_commit_sha=(sha)
        super
        self.succeeded = true unless merge_commit_sha.nil?
      end

      def update_travis_build_status(travis)
        perform_task "Received Travis build status: finished=#{travis.finished?} build_url=#{travis.build_url}" do
          if travis.finished?
            update(:travis_build_success => travis.build_success?, :travis_build_url => travis.build_url)
          else
            update(:travis_build_url => travis.build_url)
          end
        end
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

      def perform_task(message, &block)
        add_log_message(:message => message)
        begin
          self.class.db.transaction(:savepoint => true, &block)
        rescue Object => e
          if attempts == RETRY_COUNT
            update(:succeeded => false, :needs_to_perform_work => false)
          else
            update(:attempts => attempts + 1)
          end
          # TODO report full error to error reporting service
          add_log_message(:message => "Error: #{e.message}")
          TRUNK_APP_LOGGER.error "#{e.message}\n\t\t#{e.backtrace.join("\n\t\t")}"
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
          pusher_name, pusher_email = 'Eloy Durán', 'eloy.de.enige@gmail.com'
          message = "[Add] #{pod_version.pod.name} #{pod_version.name}"
          update(:new_commit_sha => github.create_new_commit(new_tree_sha,
                                                             base_commit_sha,
                                                             message,
                                                             pusher_name,
                                                             pusher_email))
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
        needs_value?(:merge_commit_sha) && travis_build_success?
      end

      task :merge_commit_sha, :if => :should_perform_merge? do
        perform_task "Merging pull-request number #{pull_request_number}" do
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

