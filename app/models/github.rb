require 'rest'
require 'json'
require 'uri'
require 'base64'

module Pod
  module TrunkApp
    class GitHub
      BASE_URL = "https://api.github.com/repos/%s".freeze
      HEADERS  = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }.freeze
      BRANCH   = 'master'

      attr_reader :basic_auth

      # `repo_name` should be in the form of 'owner/repo'.
      def initialize(repo_name, basic_auth)
        @base_url   = BASE_URL % repo_name
        @basic_auth = basic_auth
      end

      def create_new_commit(destination_path, data, message, author_name, author_email)
        rest(:put, File.join('contents', URI.escape(destination_path)), {
          :message   => message,
          :branch    => BRANCH,
          :content   => Base64.encode64(data).delete("\r\n"),
          :author    => { :name => author_name,        :email => author_email },
          :committer => { :name => ENV['GH_USERNAME'], :email => ENV['GH_EMAIL'] },
        })['commit']['sha']
      end

      def url_for(path)
        File.join(@base_url, path)
      end

      private

      def rest(method, path, body)
        response = perform_request(method, path, body)
        JSON.parse(response.body) if response.body
      end

      def perform_request(method, path, body)
        response = REST.send(method, url_for(path), body.to_json, HEADERS, @basic_auth)
        # TODO Make this pretty mkay
        if (400...600).include?(response.status_code)
          raise "[#{response.status_code}] #{response.headers.inspect} – #{response.body}}"
        end
        response
      end
    end
  end
end
