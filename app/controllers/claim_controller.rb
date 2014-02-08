
require 'sinatra/twitter-bootstrap'
require 'sinatra/reloader'
require 'slim'


module Pod
  module TrunkApp
    class ClaimController < AppController

      configure do
        set :views, settings.root + '/app/views/claims'
      end

      get '' do
        slim :'show'
      end

    end
  end
end

