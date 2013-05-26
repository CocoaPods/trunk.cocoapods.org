require 'app/models/submission_job'

module Pod
  module PushApp
    class PodVersion < Sequel::Model
      self.dataset = :pod_versions
      plugin :timestamps

      many_to_one :pod
      one_to_many :submission_jobs

      def published?
        published
      end
    end
  end
end
