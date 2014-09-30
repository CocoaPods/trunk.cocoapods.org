require 'app/controllers/html_controller'
require 'app/helpers/manage_helper'
require 'app/models/pod'

require 'active_support/core_ext/hash/except'
require 'peiji_san/view_helper'
require 'sinatra/twitter-bootstrap'
require 'sinatra/url_for'

module Pod
  module TrunkApp
    class ManageController < HTMLController
      def self.hash_password(password)
        Digest::SHA2.hexdigest(password)
      end

      use Rack::Auth::Basic, 'Protected Area' do |username, password|
        username == 'admin' && hash_password(password) == ENV['TRUNK_APP_ADMIN_PASSWORD']
      end

      configure do
        enable :method_override # Enable PUT from forms.
        set :views, settings.root + '/app/views/manage'
      end

      configure :development do
        register Sinatra::Reloader
      end

      helpers ManageHelper, Sinatra::UrlForHelper, PeijiSan::ViewHelper

      register Sinatra::Twitter::Bootstrap::Assets

      get '/' do
        redirect to('/log_messages')
      end

      get '/commits' do
        @collection = Commit.page(params[:page]).order(Sequel.desc(:created_at))

        erb :'commits/index'
      end

      get '/commits/:id' do
        @commit = Commit.find(:id => params[:id])

        erb :'commits/show'
      end

      get '/pods' do
        pods = Pod.page(params[:page])
        pods = pods.where(Sequel.like(:name, /#{params[:name]}/i)) if params[:name]
        @collection = pods.order(Sequel.asc(:name))

        erb :'pods/index'
      end

      post '/pods/:name/owners' do
        pod = Pod.find(:name => params[:name])
        owner = Owner.find(:email => params[:email])
        if pod && owner
          unclaimed_owner = Owner.unclaimed

          DB.test_safe_transaction do
            if pod.owners == [unclaimed_owner]
              pod.remove_owner(unclaimed_owner)
            end

            pod.add_owner(owner)
          end

          redirect to('/pods/' + pod.name)
        else
          halt 404
        end
      end

      get '/pods/:name' do
        @pod = Pod.find(:name => params[:name])
        if @pod
          erb :'pods/detail'
        else
          halt 404
        end
      end

      post '/owners/delete' do
        owner = Owner.find(:id => params[:owner])
        pod = Pod.find(:id => params[:pod])

        pod.remove_owner owner

        pod.add_owner(Owner.unclaimed) if pod.owners.empty?

        body owner.to_json
      end

      get '/versions' do
        @collection = PodVersion.page(params[:page]).order(Sequel.desc(:id))
        erb :'pod_versions/index'
      end

      get '/log_messages' do
        reference_filter = params[:reference]
        messages = LogMessage.page(params[:page])
        messages = messages.where('reference = ?', reference_filter) if reference_filter
        @collection = messages.order(Sequel.desc(:id))
        erb :'log_messages/index'
      end

      get '/disputes' do
        disputes = Dispute.page(params[:page])
        if params[:scope] == 'unsettled'
          @collection = disputes.where(:settled => false).order(Sequel.asc(:id))
        else
          @collection = disputes.order(Sequel.desc(:id))
        end
        erb :'disputes/index'
      end

      get '/disputes/:id' do
        @dispute = Dispute.find(:id => params[:id])
        erb :'disputes/show'
      end

      put '/disputes/:id' do
        @dispute = Dispute.find(:id => params[:id])
        @dispute.update(params[:dispute])
        redirect to("/disputes/#{@dispute.id}")
      end
    end
  end
end
