require 'app/controllers/app_controller'

module Pod
  module TrunkApp
    # Relates to our Sabayon ( https://github.com/dmathieu/sabayon ) instance
    # located at https://dashboard.heroku.com/apps/cocoapods-letsencrypt-sabayon/
    #
    # Sabayon will set up SSL cert for us, to do this, we have to prove we own the domain
    # so LetsEncrypt asks for you to respond to a specific route.
    # Sabayon will set environment vars on trunk, which will trigger a restart, this
    # means at this point we can look inside our ENV vars and respond to the specific
    # request that LetsEncrypt wants.
    #
    # This class is a modified version of the Rack example in the README
    # https://github.com/dmathieu/sabayon#ruby-apps
    #
    class LetsEncryptController < AppController
      configure :development do
        register Sinatra::Reloader
      end

      get '/acme-challenge/:token' do
        data = []
        if ENV['ACME_KEY'] && ENV['ACME_TOKEN']
          data << { :key => ENV['ACME_KEY'], :token => ENV['ACME_TOKEN'] }
        else
          ENV.each do |k, v|
            if digit = k.match(/^ACME_KEY_([0-9]+)/)
              index = digit[1]
              data << { :key => v, :token => ENV["ACME_TOKEN_#{index}"] }
            end
          end
        end

        contract = data.find { |couplet| params[:token] == couplet[:token] }
        return [200, { 'Content-Type' => 'text/plain' }, [contract[:key]]] if contract

        error 404
      end
    end
  end
end
