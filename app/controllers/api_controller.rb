require 'app/controllers/app_controller'
require 'app/models/session'

require 'newrelic_rpm'

module Pod
  module TrunkApp
    class APIController < AppController
      private

      # --- Request / Response --------------------------------------------------------------------

      before do
        type = content_type(:json)
        if (request.post? || request.put?) && request.media_type != 'application/json'
          json_error(415, "Unable to accept input with Content-Type `#{request.media_type}`, " \
                          'must be `application/json`.')
        end
      end

      def json_error(status, message)
        error(status, { 'error' => message }.to_json)
      end

      def json_message(status, content)
        halt(status, content.to_json)
      end

      # --- Errors --------------------------------------------------------------------------------

      configure :development do
        # Otherwise our handlers below aren't used in development mode.
        set :show_exceptions, :after_handler
      end

      error JSON::ParserError do
        json_error(400, 'Invalid JSON data provided.')
      end

      error Sequel::ValidationFailed do |error|
        json_error(422, error.errors)
      end

      def catch_unexpected_errors?
        settings.environment != :test
      end

      error 500 do |*args|
        # Unless a specific HTTP 500 response was thrown, this is a bubbled-up exception.
        if error = args.first
          if catch_unexpected_errors?
            NewRelic::Agent.notice_error(error, :uri => request.path,
                                                :referer => request.referrer.to_s,
                                                :request_params => request.params)
            throw_internal_server_error!
          else
            raise error
          end
        end
      end

      def throw_internal_server_error!
        # TODO: Update with our status page address.
        json_error(500, 'An internal server error occurred. Please check for any known status ' \
                        'issues at https://twitter.com/CocoaPods and try again later.')
      end

      # --- Authentication ------------------------------------------------------------------------

      # Always try to find the owner and prolong the session.
      #
      before do
        if @session = Session.with_token(authentication_token)
          @owner = @session.owner
          @session.prolong!
        end
      end

      # Returns if there is an authenticated owner or throws an error in case there isn't.
      #
      set :requires_owner do |required|
        condition do
          if required && @owner.nil?
            if authentication_token.blank?
              json_error(401, 'Please supply an authentication token.')
            else
              json_error(401, 'Authentication token is invalid or ' \
                              'unverified. Either verify it with the email ' \
                              'that was sent or register a new session.')
            end
          end
        end
      end

      class << self
        # Override all the route methods to ensure an ACL rule is specified.
        #
        [:get, :post, :put, :patch, :delete].each do |verb|
          class_eval <<-EOS, __FILE__, __LINE__ + 1
            def #{verb}(route, options, &block)
              unless options.has_key?(:requires_owner)
                raise "Must specify a ACL rule for #{name} #{verb.to_s.upcase} \#{route}"
              end
              super
            end
          EOS
        end
      end

      # Returns the Authorization header if the value of the header starts with ‘Token’.
      #
      def authorization_header
        authorization = env['HTTP_AUTHORIZATION'].to_s.strip
        unless authorization == ''
          if authorization.start_with?('Token')
            authorization
          end
        end
      end

      # Returns the token value from the Authorization header if the header starts with ‘Token’.
      #
      def token_from_authorization_header
        if authorization = authorization_header
          authorization.split(' ', 2)[-1]
        end
      end

      # Returns the authentication token from any possible location.
      #
      # Currently supported is the Authorization header.
      #
      #   Authorization: Token 34jk45df98
      #
      def authentication_token
        if token = token_from_authorization_header
          logger.debug("Got authentication token: #{token}")
          token
        end
      end
    end
  end
end
