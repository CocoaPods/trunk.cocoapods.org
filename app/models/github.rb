require 'rest'
require 'json'

module Pod
  module PushApp
    class GitHub
      BASE_URL   = "https://api.github.com/repos/#{ENV['GH_REPO']}".freeze # GH_REPO should be in the form of 'owner/repo'
      BASIC_AUTH = { :username => ENV['GH_USERNAME'], :password => ENV['GH_PASSWORD'] }.freeze
      HEADERS    = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }.freeze

      attr_reader :path, :contents

      def initialize(path, contents)
        @path, @contents = path, contents
      end

      def url_for(path)
        File.join(BASE_URL, path)
      end

      def sha_latest_commit
        response = REST.get(url_for('git/refs/heads/master'), HEADERS, BASIC_AUTH)
        JSON.parse(response.body)['object']['sha']
      end

      def sha_base_tree
        response = REST.get(url_for("git/commits/#{sha_latest_commit}"), HEADERS, BASIC_AUTH)
        JSON.parse(response.body)['tree']['sha']
      end
    end
  end
end
