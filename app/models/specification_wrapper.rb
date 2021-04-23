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
        return true unless url.include?('github.com/')

        owner_name = url.split('github.com/')[1].split('/')[0]
        repo_name = url.split('github.com/')[1].split('/')[1]
        return false unless owner_name && repo_name

        # Drop the optional .git reference in a url
        repo_name = repo_name[0...-4] if repo_name.end_with? '.git'

        # Use the GH refs API for tags and branches
        ref = 'refs/head'
        ref = "refs/tags/#{@specification.source[:tag]}" if @specification.source[:tag]
        ref = "refs/heads/#{@specification.source[:branch]}" if @specification.source[:branch]
        ref = "commits/#{@specification.source[:commit]}" if @specification.source[:commit]

        api_path = "https://api.github.com/repos/#{owner_name}/#{repo_name}/git/#{ref}"

        gh = GitHub.new(ENV['GH_REPO'], :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic')
        wrap_timeout do
          req = gh.head(api_path)
          return true if req.success?

          # Did they rename, or send the repo elsewhere?
          if req.status_code == 301
            return gh.head(req).success?
          else
            false
          end
        end
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
