require 'rest'
require 'json'

module Pod
  module TrunkApp
    class GitHub
      BASE_URL = "https://api.github.com/repos/%s".freeze
      HEADERS  = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }.freeze

      # `repo_name` should be in the form of 'owner/repo'.
      def initialize(repo_name, base_branch_ref, basic_auth)
        @base_url = BASE_URL % repo_name
        @base_branch_ref, @basic_auth = base_branch_ref, basic_auth
      end

      def fetch_latest_commit_sha
        rest(:get, "git/#{branch_ref(@base_branch_ref)}")['object']['sha']
      end

      def fetch_base_tree_sha(commit_sha)
        rest(:get, "git/commits/#{commit_sha}")['tree']['sha']
      end

      def create_new_tree(base_tree_sha, destination_path, data)
        rest(:post, 'git/trees', {
          :base_tree => base_tree_sha,
          :tree => [{
            :encoding => 'utf-8',
            :mode     => '100644',
            :path     => destination_path,
            :content  => data
          }]
        })['sha']
      end

      def create_new_commit(new_tree_sha, base_commit_sha, message, author_name, author_email)
        rest(:post, 'git/commits', {
          :parents   => [base_commit_sha],
          :tree      => new_tree_sha,
          :message   => message,
          :author => {
            :name  => author_name,
            :email => author_email,
          },
          :committer => {
            :name  => ENV['GH_USERNAME'],
            :email => ENV['GH_EMAIL'],
          },
        })['sha']
      end

      private

      def branch_ref(name)
        "refs/heads/#{name}"
      end

      def url_for(path)
        File.join(@base_url, path)
      end

      def rest(method, path, body = nil)
        args = [method, url_for(path), (body.to_json if body), HEADERS, @basic_auth].compact
        response = REST.send(*args)
        # TODO Make this pretty mkay
        if (400...600).include?(response.status_code)
          raise "[#{response.status_code}] #{response.headers.inspect} – #{response.body}}"
        end
        JSON.parse(response.body) if response.body
      end
    end
  end
end
