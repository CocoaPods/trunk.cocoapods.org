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
        CreateCommitResponse.new(response)
      end

      def url_for(path)
        File.join(@base_url, path)
      end

      private

      def put(path, body)
        REST.put(url_for(path), body.to_json, HEADERS, @basic_auth)
      end

      public

      class CreateCommitResponse
        def self.response(status, body = nil)
          new(REST::Response.new(status, {}, body))
        end

        def initialize(response)
          @response = response
          case @response.status_code
          when 200...400
            # no-op
          when 400...500
            @failed_on_our_side = true
          when 500...600
            @failed_on_their_side = true
          else
            raise "returned an unexpected HTTP response: #{response.inspect}"
          end
        end

        def status_code
          @response.status_code
        end

        def body
          @response.body
        end

        def failed_on_our_side?
          @failed_on_our_side
        end

        def failed_on_their_side?
          @failed_on_their_side
        end

        def success?
          !failed_on_our_side? && !failed_on_their_side?
        end

        def commit_sha
          @commit_sha ||= JSON.parse(@response.body)['commit']['sha']
        end
      end

    end
  end
end
