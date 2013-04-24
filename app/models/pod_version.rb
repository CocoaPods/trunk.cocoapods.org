require 'app/models/submission_job'

module Pod
  module PushApp
    class PodVersion < Sequel::Model
      self.dataset = :pod_versions
      plugin :timestamps

      many_to_one :pod
      one_to_one :submission_job

      def after_create
        super
        self.submission_job = SubmissionJob.create
      end

      # TODO I'm sure there's a better way to enable this through Sequel.
      def published?
        published
      end

      # TODO this should move to the submission job
      def submitted_as_pull_request!
        update :state => 'submitted_as_pull_request'
      end
      def submitted_as_pull_request?
        state == 'submitted_as_pull_request'
      end
    end
  end
end
