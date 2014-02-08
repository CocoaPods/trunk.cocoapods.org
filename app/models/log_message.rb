require 'app/models/submission_job'

module Pod
  module TrunkApp
    class LogMessage < Sequel::Model
      self.dataset = :log_messages

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :submission_job

      def public_attributes
        { created_at => message }
      end

      protected

      def validate
        super
        validates_presence :submission_job_id
        validates_presence :message
      end
    end
  end
end

