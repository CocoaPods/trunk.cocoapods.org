require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'
require 'app/concerns/git_commit_sha_validator'

module Pod
  module TrunkApp
    class Commit < Sequel::Model
      include Concerns::GitCommitSHAValidator

      self.dataset = :commits

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :pod_version
      # one_to_many :log_messages, :order => Sequel.asc(:created_at)

      def in_progress?
        pushed.nil?
      end

      protected

      def validate
        super
        validates_presence :pod_version_id
        validates_presence :specification_data
        validates_git_commit_sha :sha # TODO Allow empty sha?
      end
    end
  end
end

