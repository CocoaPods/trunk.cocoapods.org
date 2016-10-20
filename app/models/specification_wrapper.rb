require 'cocoapods-core'
require 'shellwords'
require 'timeout'

module Pod
  module TrunkApp
    class SpecificationWrapper
      def self.from_json(json)
        hash = JSON.parse(json)
        if hash.is_a?(Hash)
          new(Specification.from_hash(hash))
        end
      rescue JSON::ParserError
        # TODO: report error?
        nil
      end

      def initialize(specification)
        @specification = specification
      end

      def name
        @specification.name
      end

      def version
        @specification.version.to_s
      end

      def to_s
        @specification.to_s
      end

      def to_json(*a)
        @specification.to_json(*a)
      end

      def to_pretty_json(*a)
        @specification.to_pretty_json(*a)
      end

      def valid?(allow_warnings: false)
        linter.lint
        linter.results.send(:results).reject! do |result|
          result.type == :warning && result.attribute_name == 'attributes' && result.message == 'Unrecognized `pushed_with_swift_version` key.'
        end
        allow_warnings ? linter.errors.empty? : linter.results.empty?
      end

      def validation_errors(allow_warnings: false)
        results = {}
        results['warnings'] = remove_prefixes(linter.warnings) unless allow_warnings || linter.warnings.empty?
        results['errors']   = remove_prefixes(linter.errors)   unless linter.errors.empty?
        results
      end

      def publicly_accessible?
        return validate_http if @specification.source[:http]
        return validate_git if @specification.source[:git]
        true
      end

      private

      def wrap_timeout(&blk)
        Timeout.timeout(5) do
          blk.call
        end
      rescue Timeout::Error
        false
      end

      def validate_http
        wrap_timeout { HTTP.validate_url(@specification.source[:http]) }
      end

      def validate_git
        # We've had trouble with Heroku's git install, see trunk.cocoapods.org/pull/141
        url = @specification.source[:git]
        return true unless url.include?('github.com') || url.include?('bitbucket.org')

        ref = @specification.source[:tag] ||
          @specification.source[:commit] ||
          @specification.source[:branch] ||
          'HEAD'
        wrap_timeout { system('git', 'ls-remote', @specification.source[:git], ref.to_s) }
      end

      def linter
        @linter ||= Specification::Linter.new(@specification)
      end

      def remove_prefixes(results)
        results.map do |result|
          result.message.sub(/^\[.+?\]\s*/, '')
        end
      end
    end
  end
end
