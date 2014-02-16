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

      # @param [String] repo_name  Should be in the form of 'owner/repo'.
      #
      def initialize(repo_name, basic_auth)
        @base_url   = BASE_URL % repo_name
        @basic_auth = basic_auth
      end

      # @return [REST::Response,CommitResponseExt] A HTTP response object extended to return the
      #                                            `commit_sha`.
      #
      def create_new_commit(destination_path, data, message, author_name, author_email)
        response = put(File.join('contents', URI.escape(destination_path)), {
          :message   => message,
          :branch    => BRANCH,
          :content   => Base64.encode64(data).delete("\r\n"),
          :author    => { :name => author_name,        :email => author_email },
          :committer => { :name => ENV['GH_USERNAME'], :email => ENV['GH_EMAIL'] },
        })
        response.extend(CommitResponseExt)
        response
      end

      def url_for(path)
        File.join(@base_url, path)
      end

      private

      def put(path, body)
        REST.put(url_for(path), body.to_json, HEADERS, @basic_auth)
      end

      module CommitResponseExt
        def commit_sha
          JSON.parse(body)['commit']['sha']
        end
      end
    end
  end
end
