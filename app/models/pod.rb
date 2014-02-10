require 'app/models/pod_version'

module Pod
  module TrunkApp
    class Pod < Sequel::Model
      self.dataset = :pods

      plugin :timestamps
      plugin :validation_helpers

      one_to_many :versions, :class => 'Pod::TrunkApp::PodVersion'
      many_to_many :owners

      # Finds a pod by name.
      #
      # If the pod has owners but the specified user is not one of the owners the 'no access
      # allowed' block will be called.
      #
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

      protected

      def validate
        super
        validates_presence :name
        validates_unique :name
      end
    end
  end
end
