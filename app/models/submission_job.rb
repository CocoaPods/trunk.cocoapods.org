require 'app/models/pod_version'
require 'app/models/log_message'

module Pod
  module PushApp
    class SubmissionJob < Sequel::Model
      self.dataset = :submission_jobs
      plugin :timestamps

      many_to_one :pod_version
      one_to_many :log_messages

      def after_create
        super
        add_log_message(:message => 'Submitted')
      end
    end
  end
end

