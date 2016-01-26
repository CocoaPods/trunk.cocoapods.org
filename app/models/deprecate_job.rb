require 'app/models/pod_version'

module Pod
  module TrunkApp
    class DeprecateJob
      attr_reader :pod, :committer, :in_favor_of

      def initialize(pod, committer, in_favor_of = nil)
        @pod = pod
        @committer = committer
        @in_favor_of = in_favor_of
      end

      def deprecate!
        versions = pod.versions.reject(&:deleted?)
        versions.map { |version| version.deprecate!(committer, in_favor_of) }.compact
      end
    end
  end
end
