require 'rest'
require 'json'
require 'uri'
require 'base64'

module Pod
  module TrunkApp
    class GitHub
      BASE_URL = 'https://api.github.com/repos/%s'.freeze
      HEADERS  = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }.freeze
      BRANCH   = 'master'

      attr_reader :basic_auth

      # @param [String] repo_name  Should be in the form of 'owner/repo'.
      #
      def initialize(repo_name, basic_auth)
        @base_url   = BASE_URL % repo_name
        @basic_auth = basic_auth
      end

      # @return [CommitResponse] A encapsulated response object that parses the `commit_sha`.
      #
      def create_new_commit(destination_path, data, message, author_name, author_email, update: false)
        CommitResponse.new do
          put(File.join('contents', URI.escape(destination_path)),
              :message   => message,
              :branch    => BRANCH,
              :sha       => (sha_for_file_at_path(destination_path) if update),
              :content   => Base64.encode64(data).delete("\r\n"),
              :author    => { :name => author_name,        :email => author_email },
              :committer => { :name => ENV['GH_USERNAME'], :email => ENV['GH_EMAIL'] },
             )
        end
      end

      # @return [CommitResponse] A encapsulated response object that deletes a file at a path
      #
      def delete_file_at_path(destination_path, message, author_name, author_email)
        CommitResponse.new do
          delete(File.join('contents', URI.escape(destination_path)),
                 :message   => message,
                 :sha       => sha_for_file_at_path(destination_path),
                 :author    => { :name => author_name,        :email => author_email },
                 :committer => { :name => ENV['GH_USERNAME'], :email => ENV['GH_EMAIL'] },
                )
        end
      end

      # @return [CommitResponse] A encapsulated response object that gets the SHA associated with a file at a path
      #
      def file_for_path(path)
        CommitResponse.new do
          get(File.join('contents', URI.escape(path)))
        end
      end

      # @return [String, Nil] The SHA for the file at the given path, or `nil`
      #         if there is no file at the given path.
      #
      def sha_for_file_at_path(path)
        response = file_for_path(path)
        JSON.parse(response.body)['sha'] if response.success?
      end

      # @return [String] A full API route for a path
      #
      def url_for(path)
        File.join(@base_url, path)
      end

      # Perform a GET request.
      #
      def get(path)
        perform_request(:get, path, '')
      end

      # Performs a PUT request.
      #
      def put(path, body)
        perform_request(:put, path, body)
      end

      # Performs a DELETE request.
      #
      def delete(path, body)
        perform_request(:delete, path, body)
      end

      private

      # Performs an HTTP request with a max timeout of 10 seconds
      # TODO: timeout could probably even be less.
      def perform_request(method, path, body)
        REST::Request.perform(method, URI.parse(url_for(path)), body.to_json, HEADERS, @basic_auth) do |http_request|
          http_request.open_timeout = 3
          http_request.read_timeout = 7
        end
      end

      class CommitResponse
        attr_reader :timeout_error

        def initialize
          @response = yield
          case @response.status_code
          when 200...400
            # no-op
          when 400...500
            @failed_on_our_side = true
          when 500...600
            @failed_on_their_side = true
          else
            raise "returned an unexpected HTTP response: #{@response.inspect}"
          end
        rescue REST::Error::Timeout => e
          @timeout_error = "[#{e.class.name}] #{e.message}"
        end

        # @return [Number] The status code for the HTTP response
        def status_code
          @response.status_code
        end

        # @return [String] The body for the HTTP response
        def body
          @response.body
        end

        # @return [String] The header value for a specific key on the HTTP response
        def header(name)
          @response[name]
        end

        attr_reader :failed_on_our_side
        alias_method :failed_on_our_side?, :failed_on_our_side

        attr_reader :failed_on_their_side
        alias_method :failed_on_their_side?, :failed_on_their_side

        def failed_due_to_timeout?
          !@timeout_error.nil?
        end

        # @return [Bool] Was the HTTP request successful?
        def success?
          !failed_on_our_side? && !failed_on_their_side? && !failed_due_to_timeout?
        end

        def commit_sha
          @commit_sha ||= JSON.parse(body)['commit']['sha']
        end
      end
    end
  end
end
