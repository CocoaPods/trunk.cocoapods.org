require 'app/models/submission_job'

module Pod
  module TrunkApp
    class PodVersion < Sequel::Model
      self.dataset = :pod_versions
      plugin :timestamps

      many_to_one :pod
      many_to_one :published_by_submission_job, :class => 'Pod::TrunkApp::SubmissionJob'
      one_to_many :submission_jobs, :order => Sequel.asc(:id)

      alias_method :published?, :published
    end
  end
end
