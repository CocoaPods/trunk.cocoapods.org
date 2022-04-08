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

      alias deleted? deleted

      # Finds a pod by name, only including deleted pods if `include_deleted` is
      # true.
      #
      def self.find_by_name(name, include_deleted: false)
        if include_deleted
          find(:name => name)
        else
          find(:deleted => false, :name => name)
        end
      end

      # Finds a pod by name that has *not* been deleted.
      #
      # If the pod has owners but the specified user is not one of the owners the 'no access
      # allowed' block will be called.
      #
      def self.find_by_name_and_owner(name, owner, include_deleted: false)
        if pod = find_by_name(name, :include_deleted => include_deleted)
          if pod.owners.include?(owner)
            return pod
          elsif block_given?
            yield pod
          end
        end
        nil
      end

      def after_initialize
        super
        @was_created = new?
      end

      attr_reader :was_created
      alias was_created? was_created

      def public_attributes
        {
          'name' => name,
          'created_at' => created_at,
          'updated_at' => updated_at,
        }
      end

      def name=(name)
        self.normalized_name = name.downcase if name
        super
      end

      protected

      def validate
        super
        validates_presence :name
        validates_unique :normalized_name
        if error = errors.delete(:normalized_name)
          errors.add(:name, error.first)
        end
      end
    end
  end
end
