require 'rack/ssl'
require 'sinatra/base'

require 'config/init'

# First define the base controller class.
module Pod
  module TrunkApp
    class AppController < Sinatra::Base
      configure do
        set :root, ROOT
      end

      configure :development, :production do
        enable :logging
      end

      use Rack::SSL unless ENV['RACK_ENV'] == 'development'
    end
  end
end

# Now load subclass controllers.
require 'app/controllers/api/pods_controller'
require 'app/controllers/api/sessions_controller'
require 'app/controllers/manage_controller'
require 'app/controllers/claim_controller'

# And assemble base routes to controllers map.
module Pod
  module TrunkApp
    App = Rack::URLMap.new(
      '/api/v1/pods'     => PodsController,
      '/api/v1/sessions' => SessionsController,
      '/manage'          => ManageController,
      '/claim'           => ClaimController,
    )
  end
end
