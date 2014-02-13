require 'app/models/push_job'

module Pod
  module TrunkApp
    class LogMessage < Sequel::Model
      self.dataset = :log_messages

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :push_job

      def public_attributes
        { created_at => message }
      end

      protected

      def validate
        super
        validates_presence :push_job_id
        validates_presence :message
      end
    end
  end
end

