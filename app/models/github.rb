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

      def create_new_commit(message)
        rest(:post, 'git/commits', :parents => [sha_latest_commit], :tree => create_new_tree, :message => message)['sha']
      end

      def create_new_branch(name, commit_sha)
        rest(:post, 'git/refs', :ref => branch_ref(name), :sha => commit_sha)['ref']
      end

      def create_pull_request(title, body, branch_name)
        rest(:post, 'pulls', :title => title, :body => body, :head => branch_ref(branch_name), :base => branch_ref(BASE_BRANCH))['number']
      end

      protected

      def sha_latest_commit
        @sha_latest_commit ||= rest(:get, "git/#{branch_ref(BASE_BRANCH)}")['object']['sha']
      end

      def sha_base_tree
        @sha_base_tree ||= rest(:get, "git/commits/#{sha_latest_commit}")['tree']['sha']
      end

      def create_new_tree
        rest(:post, 'git/trees', {
          :base_tree => sha_base_tree,
          :tree => [{
            :encoding => 'utf-8',
            :mode     => '100644',
            :path     => @destination_path,
            :content  => @content
          }]
        })['sha']
      end

      private

      def branch_ref(name)
        "refs/heads/#{name}"
      end

      def url_for(path)
        File.join(BASE_URL, path)
      end

      # TODO handle failures
      def rest(method, path, body = nil)
        args = [method, url_for(path), (body.to_json if body), HEADERS, BASIC_AUTH].compact
        response = REST.send(*args)
        JSON.parse(response.body)
      end
    end
  end
end
