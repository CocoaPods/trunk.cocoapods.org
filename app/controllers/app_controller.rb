require 'rack/ssl'
require 'sinatra/base'

require 'config/init'

module Pod
  module TrunkApp
    # Our custom request logger for development purposes.
    class RequestLogger < Rack::CommonLogger
      class AppendLogger
        def initialize(logger, message)
          @logger = logger
          @message = message
        end

        def write(msg)
          @logger.write(msg)
          @logger.write(@message)
        end
      end

      # Temporarily inject a proxy logger that we append our message to.
      def log(env, status, header, began_at)
        logger_before = env['rack.errors']
        params = env['rack.request.query_hash']
        params = params.merge(env['rack.request.form_hash']) if env['rack.request.form_hash']
        env['rack.errors'] = AppendLogger.new(logger_before, "#{params.inspect}\n")
        super(env, status, header, began_at)
      ensure
        env['rack.errors'] = logger_before
      end
    end

    # First define the base controller class.
    class AppController < Sinatra::Base
      configure do
        set :root, ROOT
        set :views, settings.root + '/app/views'
      end

      configure :production do
        enable :logging
      end

      configure :development do
        use RequestLogger
      end

      use Rack::SSL unless ENV['RACK_ENV'] == 'development'
    end
  end
end

# Now load subclass controllers.
require 'app/controllers/api/pods_controller'
require 'app/controllers/api/sessions_controller'
require 'app/controllers/api/owners_controller'
require 'app/controllers/session_verification_controller'
require 'app/controllers/hooks_controller'
require 'app/controllers/manage_controller'
require 'app/controllers/assets_controller'
require 'app/controllers/letsencrypt_controller'

# TODO: Temporary controller while we transition to the trunk app.
require 'app/controllers/claims_controller'

# And assemble base routes to controllers map.
module Pod
  module TrunkApp
    App = Rack::URLMap.new(
      '/api/v1/pods'     => PodsController,
      '/api/v1/sessions' => SessionsController,
      '/api/v1/owners'   => OwnersController,
      '/sessions'        => SessionVerificationController,
      '/hooks'           => HooksController,
      '/manage'          => ManageController,
      '/assets'          => AssetsController,
      '/.well-known'     => LetsEncryptController,

      # TODO: Temporary routes while we transition to the trunk app.
      '/claims'          => ClaimsController,
      '/'                => HTMLController,
    )
  end
end
