module Pod
  module PushApp
    class PodVersion < Sequel::Model
      self.dataset = :pod_versions
      plugin :timestamps

      many_to_one :pod

      def submitted_as_pull_request!
        update :state => 'submitted_as_pull_request'
      end

      def submitted_as_pull_request?
        state == 'submitted_as_pull_request'
      end
    end
  end
end
