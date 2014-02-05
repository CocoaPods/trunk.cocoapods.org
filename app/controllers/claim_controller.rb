
require 'sinatra/twitter-bootstrap'

module Pod
  module TrunkApp
    class ClaimController < AppController

      configure do
        set :views, settings.root + '/app/views/claims'
      end

      register Sinatra::Twitter::Bootstrap::Assets

      get '' do
        erb :'show'
      end

    end
  end
end

