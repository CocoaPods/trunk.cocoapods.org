require 'json'
require 'digest'

module Pod
  module TrunkApp
    class Travis
      def self.webhook_authorization_token
        Digest::SHA2.hexdigest(ENV['GH_REPO'] + ENV['TRAVIS_API_TOKEN'])
      end

      def self.authorized_webhook_notification?(token)
        webhook_authorization_token == token
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

      TRAVIS_BUILD_URL = File.join('https://travis-ci.org', ENV['GH_REPO'], 'builds/%d')

      def build_url
        @payload['build_url'] ||= (TRAVIS_BUILD_URL % id)
      end
    end
  end
end
