require 'app/controllers/app_controller'
require 'app/helpers/manage_helper'
require 'app/models/pod'

require 'sinatra/twitter-bootstrap'

module Pod
  module TrunkApp
    class ManageController < AppController
      def self.hash_password(password)
        Digest::SHA2.hexdigest(password)
      end

      use Rack::Auth::Basic, 'Protected Area' do |username, password|
        username == 'admin' && hash_password(password) == ENV['TRUNK_APP_ADMIN_PASSWORD']
      end

      configure do
        set :views, settings.root + '/app/views/manage'
      end

      configure :development do
        register Sinatra::Reloader
      end

      helpers ManageHelper

      register Sinatra::Twitter::Bootstrap::Assets

      get '/' do
        redirect to('/log_messages')
      end

      get '/commits' do
        @commits = Commit.all
        erb :'commits/index'
      end

      get '/commits/:id' do
        @commit = Commit.find(:id => params[:id])
        erb :'commits/show'
      end

      get '/versions' do
        @versions = PodVersion.order(Sequel.desc(:id))
        erb :'pod_versions/index'
      end
      
      get '/log_messages' do
        reference_filter = params[:reference]
        messages = LogMessage
        messages = messages.where('reference = ?', reference_filter) if reference_filter
        @log_messages = messages.order(Sequel.desc(:id))
        erb :'log_messages/index'
      end
    end
  end
end
