require 'rest'
require 'json'

module Pod
  module PushApp
    class GitHub
      REPO        = ENV['GH_REPO'].dup.freeze
      BASE_URL    = "https://api.github.com/repos/#{REPO}".freeze # GH_REPO should be in the form of 'owner/repo'
      BASE_BRANCH = 'master'.freeze
      BASIC_AUTH  = { :username => ENV['GH_USERNAME'], :password => ENV['GH_PASSWORD'] }.freeze
      HEADERS     = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }.freeze

      def self.create_pull_request(title, body, branch_name, destination_path, content)
        github = new(destination_path, content)
        sha_new_commit = github.create_new_commit(title)
        ref_new_branch = github.create_new_branch(branch_name, sha_new_commit)
        github.create_pull_request(title, body, ref_new_branch)
      end

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

      def create_pull_request(title, body, from_branch_ref)
        rest(:post, 'pulls', :title => title, :body => body, :head => from_branch_ref, :base => branch_ref(BASE_BRANCH))['number']
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
