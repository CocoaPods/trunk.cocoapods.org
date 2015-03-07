require 'app/models/pod_version'

module Pod
  module TrunkApp
    class DeprecateJob
      attr_reader :pod, :committer, :in_favor_of

      def initialize(pod, committer, in_favor_of = nil)
        @pod, @committer, @in_favor_of = pod, committer, in_favor_of
      end

      def deprecate!
        pod.versions.map { |version| version.deprecate!(committer, in_favor_of) }.compact
      end
    end
  end
end
