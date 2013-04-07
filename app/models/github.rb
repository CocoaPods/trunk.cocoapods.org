require 'rest'
require 'json'

module Pod
  module PushApp
    class GitHub
      BASE_URL    = "https://api.github.com/repos/#{ENV['GH_REPO']}".freeze # GH_REPO should be in the form of 'owner/repo'
      BASE_BRANCH = 'master'.freeze
      BASIC_AUTH  = { :username => ENV['GH_USERNAME'], :password => ENV['GH_PASSWORD'] }.freeze
      HEADERS     = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }.freeze

      attr_reader :destination_path, :content

      def initialize(destination_path, content)
        @destination_path, @content = destination_path, content
      end

      def url_for(path)
        File.join(BASE_URL, path)
      end

      def sha_latest_commit
        response = REST.get(url_for("git/#{branch_ref(BASE_BRANCH)}"), HEADERS, BASIC_AUTH)
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

      def create_new_branch(name, commit_sha)
        body = {
          :ref => branch_ref(name),
          :sha => commit_sha
        }.to_json
        response = REST.post(url_for('git/refs'), body, HEADERS, BASIC_AUTH)
        JSON.parse(response.body)['ref']
      end

      def create_pull_request(title, body, branch_name)
        body = {
          :title => title,
          :body  => body,
          :head  => branch_ref(branch_name),
          :base  => branch_ref(BASE_BRANCH)
        }.to_json
        response = REST.post(url_for('pulls'), body, HEADERS, BASIC_AUTH)
        JSON.parse(response.body)['number']
      end

      private

      def branch_ref(name)
        "refs/heads/#{name}"
      end
    end
  end
end
