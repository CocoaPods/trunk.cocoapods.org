require 'app/models/submission_job'

module Pod
  module TrunkApp
    class PodVersion < Sequel::Model
      DATA_URL = "https://raw.github.com/#{ENV['GH_REPO']}/%s/%s"
      GIT_COMMIT_SHA_LENGTH = 40

      self.dataset = :pod_versions

      plugin :timestamps
      plugin :validation_helpers
      plugin :after_initialize

      many_to_one :pod
      many_to_one :published_by_submission_job, :class => 'Pod::TrunkApp::SubmissionJob'
      one_to_many :submission_jobs, :order => Sequel.asc(:id)

      alias_method :published?, :published

      def after_initialize
        super
        if new?
          self.published = false if published.nil?
        end
      end

      def public_attributes
        { 'created_at' => created_at, 'name' => name }
      end

      def destination_path
        File.join('Specs', pod.name, name, "#{pod.name}.podspec.json")
      end

      def data_url
        DATA_URL % [commit_sha, destination_path] if commit_sha
      end

      def resource_path
        URI.escape("/pods/#{pod.name}/versions/#{name}")
      end

      protected

      def validate
        super
        validates_presence :name
        validates_unique [:pod_id, :name]
        validates_presence :published
        validates_format /[0-9a-f]{#{GIT_COMMIT_SHA_LENGTH}}/, :commit_sha, :allow_nil => true
      end
    end
  end
end
