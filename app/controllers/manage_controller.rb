require 'sinatra/base'
require 'sinatra/twitter-bootstrap'
require 'cocoapods-core'

require 'db/config'
require 'app/models/pod'

module Pod
  module PushApp
    class ManageController < Sinatra::Base
      register Sinatra::Twitter::Bootstrap::Assets

      configure :development, :production do
        enable :logging
        set :root, ROOT
        set :views, settings.root + '/app/views/manage'
      end

      get '/jobs' do
        erb :'jobs/index'
      end
    end
  end
end
