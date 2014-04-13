require 'sinatra/twitter-bootstrap'

module Pod
  module TrunkApp
    class SessionVerificationController < AppController
      configure do
        set :views, settings.root + '/app/views/session_verification'
      end

      configure :development do
        register Sinatra::Reloader
      end

      register Sinatra::Twitter::Bootstrap::Assets

      get '/verify/:token' do
        if session = Session.with_verification_token(params[:token])
          # session.verify!
          slim :'verified'
        else
          error 404
        end
      end
    end
  end
end
