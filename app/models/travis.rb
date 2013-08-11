require 'rest'
require 'json'
require 'digest'

module Pod
  module TrunkApp
    class Travis
      TRAVIS_BUILDS_API_URL = File.join('https://api.travis-ci.org/repos', ENV['GH_REPO'], 'builds')
      TRAVIS_BUILD_WEB_URL  = File.join('https://travis-ci.org', ENV['GH_REPO'], 'builds/%d')
      MAX_NUMBER_OF_BUILDS  = 20

      def self.webhook_authorization_token
        Digest::SHA2.hexdigest(ENV['GH_REPO'] + ENV['TRAVIS_API_TOKEN'])
      end

      def self.authorized_webhook_notification?(token)
        webhook_authorization_token == token
      end

      def self.web_url_for_id(id)
        TRAVIS_BUILD_WEB_URL % id
      end

      # TODO make this breakable so it stops fetching build jobs
      def self.pull_requests
        builds = get_json(TRAVIS_BUILDS_API_URL)
        builds = builds[0..MAX_NUMBER_OF_BUILDS-1] if builds.size > MAX_NUMBER_OF_BUILDS
        builds.each do |build|
          if build['event_type'] == 'pull_request'
            yield Travis.new(get_json(File.join(TRAVIS_BUILDS_API_URL, build['id'].to_s)))
          end
        end
      end

      # TODO make this pretty and move to a place shared with github.rb
      def self.get_json(url)
        response = REST.get(url)
        if (400...600).include?(response.status_code)
          raise "[#{response.status_code}] #{response.headers.inspect} – #{response.body}}"
        end
        JSON.parse(response.body)
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

      def build_id
        @payload['id']
      end
    end
  end
end
