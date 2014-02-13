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

      helpers ManageHelper

      register Sinatra::Twitter::Bootstrap::Assets

      get '/jobs' do
        case params[:scope]
        when 'all'
          # no-op
        when 'failed'
          @jobs = PushJob.failed
        when 'succeeded'
          @jobs = PushJob.succeeded
        else
          params[:scope] = 'current'
          @jobs = PushJob.in_progress
        end

        @refresh_automatically = params[:scope] == 'current'
        erb :'jobs/index'
      end

      get '/jobs/:id' do
        @job = PushJob.find(:id => params[:id])
        if @job.in_progress? && params[:progress] != 'true'
          redirect to("/jobs/#{@job.id}?progress=true")
        else
          @refresh_automatically = @job.in_progress?
          erb :'jobs/show'
        end
      end

      get '/versions' do
        @versions = PodVersion.order(Sequel.desc(:id))
        erb :'pod_versions/index'
      end
    end
  end
end
