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

      get '/verify/:token' do
        if session = Session.with_verification_token(params[:token])
          session.verify!
          slim :verified
        else
          error 404
        end
      end
    end
  end
end
