require 'app/controllers/app_controller'

require 'sinatra/twitter-bootstrap'
#require 'sinatra/reloader'
require 'slim'

module Pod
  module TrunkApp
    class ClaimsController < AppController

      configure do
        set :views, settings.root + '/app/views/claims'
      end

      get '' do
        slim :'show'
      end

    end
  end
end

