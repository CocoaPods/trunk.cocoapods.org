require 'app/models/github'
require 'app/models/log_message'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/pod_version'
require 'app/concerns/git_commit_sha_validator'

require 'peiji_san'

module Pod
  module TrunkApp
    class Commit < Sequel::Model
      include Concerns::GitCommitSHAValidator

      self.dataset = :commits

      extend PeijiSan
      plugin :timestamps
      plugin :validation_helpers

      many_to_one :committer, :class => 'Pod::TrunkApp::Owner'
      many_to_one :pod_version

      alias_method :imported?, :imported

      def after_commit
        super
        message = {
          :type => 'commit',
          :created_at => created_at,
          :data_url => pod_version.data_url
        }.to_json
        Webhook.call(message)
      end

      protected

      def validate
        super
        validates_presence :committer_id
        validates_presence :pod_version_id
        validates_presence :specification_data
        validates_git_commit_sha :sha
      end
    end
  end
end
