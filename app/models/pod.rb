require 'app/models/pod_version'

require 'peiji_san'

module Pod
  module TrunkApp
    class Pod < Sequel::Model
      self.dataset = :pods

      extend PeijiSan
      plugin :after_initialize
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

      def after_initialize
        super
        @was_created = new?
      end

      def after_commit
        super
        Webhook.pod_created(created_at, 'TODO')
      end

      attr_reader :was_created
      alias_method :was_created?, :was_created

      protected

      def validate
        super
        validates_presence :name
        validates_unique :name
      end
    end
  end
end
