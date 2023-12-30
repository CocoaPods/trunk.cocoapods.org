require 'app/controllers/html_controller'
require 'sinatra/twitter-bootstrap'

module Pod
  module TrunkApp
    class SessionVerificationController < HTMLController
      configure :development do
        register Sinatra::Reloader
      end

      configure do
        set :views, settings.root + '/app/views/session_verification'
      end

      register Sinatra::Twitter::Bootstrap::Assets

      def shared_partial(*sources)
        sources.inject([]) do |combined, source|
          combined << Slim::Template.new("shared/includes/_#{source}.slim", {}).render
        end.join
      end

      get '/verify/:token' do
        if session = Session.with_verification_token(params[:token])
          session.verify!
          'Verified! You can close this window.'
        else
          error 404
        end
      end
    end
  end
end
