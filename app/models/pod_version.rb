require 'app/models/commit'
require 'app/concerns/git_commit_sha_validator'

require 'peiji_san'

module Pod
  module TrunkApp
    class PodVersion < Sequel::Model
      include Concerns::GitCommitSHAValidator

      DATA_URL = "https://raw.githubusercontent.com/#{ENV['GH_REPO']}/%s/%s"

      SOURCE_METADATA = Source::Metadata.new

      self.dataset = :pod_versions

      extend PeijiSan
      plugin :timestamps
      plugin :validation_helpers
      plugin :after_initialize

      trigger_webhooks = proc do |version, commit|
        pod = version.pod
        data_url = version.data_url
        Webhook.pod_created(pod.created_at, pod.name, name, commit.sha, data_url) if pod.was_created?
        Webhook.version_created(version.created_at, pod.name, name, commit.sha, data_url) if version.was_created?
        Webhook.spec_updated(commit.created_at, pod.name, name, commit.sha, data_url)
      end

      many_to_one :pod
      one_to_many :log_messages, :order => Sequel.asc(:created_at)
      one_to_many :commits,
                  :order => Sequel.asc(:created_at),
                  :after_add => trigger_webhooks

      alias_method :deleted?, :deleted

      def after_initialize
        super
        @was_created = new?
      end

      attr_reader :was_created
      alias_method :was_created?, :was_created

      def published?
        !deleted? && commits.any?
      end

      def last_published_by
        commits.last
      end

      def commit_sha
        last_published_by.sha
      end

      def public_attributes
        { 'name' => name, 'created_at' => created_at }
      end

      def destination_path
        File.join('Specs',
                  SOURCE_METADATA.path_fragment(pod.name, name),
                  "#{pod.name}.podspec.json")
      end

      def data_url
        format(DATA_URL, commit_sha, destination_path) if commit_sha
      end

      def resource_path
        URI.escape("/#{pod.name}/versions/#{name}")
      end

      def description
        "#{pod.name} #{name}"
      end

      def push!(committer, specification_data, change_type)
        response = PushJob.new(self, committer, specification_data, change_type).push!
        if response.success?
          update(:deleted => change_type == 'Delete')
          add_commit(:committer => committer, :sha => response.commit_sha, :specification_data => specification_data)
          pod.add_owner(committer) if pod.owners.empty?
        end
        pod.update(:deleted => pod.versions_dataset.count(:deleted => false).zero?)
        response
      end

      def deprecate!(committer, in_favor_of = nil)
        raise "Can't deprecate a deleted spec: #{self}" if deleted?
        spec = Specification.from_json(last_published_by.specification_data)
        raise "Unable to find a podspec to deprecate: #{self}" unless spec
        return if spec.deprecated?
        if in_favor_of
          spec.deprecated_in_favor_of = in_favor_of
        else
          spec.deprecated = true
        end
        push!(committer, spec.to_pretty_json, 'Deprecate')
      end

      def delete!(committer)
        return if deleted?
        push!(committer, '{}', 'Delete')
      end

      protected

      UNIQUE_VERSION = [:pod_id, :name]

      def validate
        super
        validates_presence :pod_id
        validates_presence :name

        validates_unique UNIQUE_VERSION
        # Sequel adds the error with the column tuple as the key, but for the
        # user just using `name' as the key is more meaningful.
        if error = errors.delete(UNIQUE_VERSION)
          errors.add(:name, error.first)
        end
      end
    end
  end
end
