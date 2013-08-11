require 'json'
require 'digest'

module Pod
  module TrunkApp
    class Travis
      TRAVIS_BUILDS_API_URL = File.join('https://api.travis-ci.org/repos', ENV['GH_REPO'], 'builds')
      TRAVIS_BUILD_WEB_URL  = File.join('https://travis-ci.org', ENV['GH_REPO'], 'builds/%d')

      def self.webhook_authorization_token
        Digest::SHA2.hexdigest(ENV['GH_REPO'] + ENV['TRAVIS_API_TOKEN'])
      end

      def self.authorized_webhook_notification?(token)
        webhook_authorization_token == token
      end

      # TODO make this breakable so it stops fetching build jobs
      def self.pull_requests
        builds_response = REST.get(TRAVIS_BUILDS_API_URL)
        # TODO errors
        builds = JSON.parse(builds_response.body)
        builds.each do |build|
          if build['event_type'] == 'pull_request'
            build_response = REST.get(File.join(TRAVIS_BUILDS_API_URL, build['id'].to_s))
            # TODO errors
            yield Travis.new(JSON.parse(build_response.body))
          end
        end
      end

      attr_reader :payload

      def initialize(payload)
        @payload = payload
      end

      def id
        @payload['id']
      end

      def pull_request?
        !pull_request_number.nil?
      end

      def pull_request_number
        type, number = @payload['compare_url'].split('/').last(2)
        number.to_i if type == 'pull'
      end

      def finished?
        !@payload['finished_at'].nil?
      end

      def build_success?
        @payload['result'] == 0
      end

      def build_url
        @payload['build_url'] ||= (TRAVIS_BUILD_WEB_URL % id)
      end
    end
  end
end
