require 'rest'
require 'json'

module Pod
  module PushApp
    class GitHub
      BASE_URL   = "https://api.github.com/repos/#{ENV['GH_REPO']}".freeze # GH_REPO should be in the form of 'owner/repo'
      BASIC_AUTH = { :username => ENV['GH_USERNAME'], :password => ENV['GH_PASSWORD'] }.freeze
      HEADERS    = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }.freeze

      attr_reader :destination_path, :content

      def initialize(destination_path, content)
        @destination_path, @content = destination_path, content
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

      def create_new_tree
        body = {
          :base_tree => sha_base_tree,
          :tree => [{
            :encoding => 'utf-8',
            :mode     => '100644',
            :path     => @destination_path,
            :content  => @content
          }]
        }.to_json
        response = REST.post(url_for('git/trees'), body, HEADERS, BASIC_AUTH)
        JSON.parse(response.body)['sha']
      end

      def create_new_commit(message)
        body = {
          :parents => [sha_latest_commit],
          :tree    => create_new_tree,
          :message => message
        }.to_json
        response = REST.post(url_for('git/commits'), body, HEADERS, BASIC_AUTH)
        JSON.parse(response.body)['sha']
      end
    end
  end
end
