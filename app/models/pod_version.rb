module Pod
  module PushApp
    class PodVersion < Sequel::Model
      self.dataset = :pod_versions
      plugin :timestamps

      many_to_one :pod

      def self.by_name_and_version(name, version_name)
        pod = Pod.find_or_create(:name => name)
        find_or_create(:pod => pod, :name => version_name)
      end

      def submitted_as_pull_request!
        update :state => 'submitted_as_pull_request'
      end

      def submitted_as_pull_request?
        state == 'submitted_as_pull_request'
      end
    end
  end
end
