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

      def initialize(payload)
        @payload = payload
      end

      def pull_request?
        !pull_request_number.nil?
      end

      def pull_request_number
        type, number = @payload['compare_url'].split('/').last(2)
        number if type == 'pull'
      end

      def pending?
        @payload['result_message'] == 'Pending'
      end

      def build_success?
        @payload['result'] == 0
      end

      def build_url
        @payload['build_url']
      end
    end
  end
end
