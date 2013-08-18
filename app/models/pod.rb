require 'app/models/pod_version'

module Pod
  module TrunkApp
    class Pod < Sequel::Model
      self.dataset = :pods
      plugin :timestamps

      one_to_many :versions, :class => 'Pod::TrunkApp::PodVersion'
      many_to_many :owners

      # Finds a pod by name.
      #
      # If the owner does not have access to the pod, the block is yielded.
      def self.find_by_name_and_owner(name, owner)
        if pod = find(:name => name)
          if pod.owners.include?(owner)
            return pod
          else
            yield if block_given?
          end
        end
        nil
      end

      def self.find_or_create_by_name_and_owner(name, owner, &block)
        find_by_name_and_owner(name, owner, &block) || owner.add_pod(:name => name)
      end
    end
  end
end
