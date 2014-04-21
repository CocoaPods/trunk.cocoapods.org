require 'app/models/push_job'

require 'peiji_san'

module Pod
  module TrunkApp
    class LogMessage < Sequel::Model
      LEVELS = [:info, :warning, :error].freeze

      self.dataset = :log_messages

      extend PeijiSan
      plugin :timestamps
      plugin :validation_helpers

      many_to_one :owner
      many_to_one :pod_version

      def public_attributes
        { created_at => message }
      end

      def level
        value = super
        value.to_sym if value
      end

      protected

      def validate
        super
        validates_presence :message
        validates_includes LEVELS, :level
      end
    end
  end
end
