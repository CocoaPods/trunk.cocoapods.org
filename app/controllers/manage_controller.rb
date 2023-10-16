require 'app/controllers/html_controller'
require 'app/helpers/manage_helper'
require 'app/models/pod'
require 'app/controllers/slack_controller'

require 'active_support/core_ext/hash/except'
require 'sinatra/twitter-bootstrap'

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

      helpers ManageHelper
      helpers do
        # @return [String]
        #
        def pod_url(pod_id)
          "/manage/pods/#{pod_id}"
        end

        # @return [String]
        #
        def pod_link(pod)
          "<a href=\"#{pod_url(pod.id)}\">#{pod.name}</a>"
        end

        # @return [String]
        #
        def commit_url(commit_id)
          "/manage/commits/#{commit_id}"
        end

        # @return [String]
        #
        def commit_link(commit)
          "<a href=\"#{commit_url(commit.id)}\">#{commit.id}</a>"
        end

        # @return [String]
        #
        def owner_url(owner_id)
          "/manage/owners/#{owner_id}"
        end

        # @return [String]
        #
        def owner_link(owner)
          "<a href=\"#{owner_url(owner.id)}\">#{owner.id}</a>"
        end
      end

      register Sinatra::Twitter::Bootstrap::Assets

      get '/' do
        redirect to('/disputes?scope=unsettled')
      end

      get '/commits' do
        @collection = Commit.order(Sequel.desc(:created_at)).page(params[:page])

        erb :'commits/index'
      end

      get '/commits/:id' do
        @commit = Commit.find(:id => params[:id])

        erb :'commits/show'
      end

      get '/pods' do
        pods = Pod
        pods = pods.where(Sequel.like(:name, /#{params[:name]}/i)) if params[:name]
        @collection = pods.order(Sequel.asc(:name)).page(params[:page])

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
        @collection = PodVersion.order(Sequel.desc(:id)).page(params[:page])
        erb :'pod_versions/index'
      end

      get '/log_messages' do
        reference_filter = params[:reference]
        messages = LogMessage
        messages = messages.where(:reference => reference_filter) if reference_filter
        @collection = messages.order(Sequel.desc(:id)).page(params[:page])
        erb :'log_messages/index'
      end

      get '/disputes' do
        disputes = Dispute.scoped
        @collection =
          if params[:scope] == 'unsettled'
            disputes.where(:settled => false).order(Sequel.asc(:id))
          else
            disputes.order(Sequel.desc(:id))
          end.page(params[:page])
        erb :'disputes/index'
      end

      get '/disputes/:id' do
        @dispute = Dispute.find(:id => params[:id])
        erb :'disputes/show'
      end

      put '/disputes/:id' do
        @dispute = Dispute.find(:id => params[:id])
        @dispute.update(params[:dispute])
        SlackController.notify_slack_of_resolved_dispute(@dispute) if params[:dispute][:settled]
        redirect to("/disputes/#{@dispute.id}")
      end
    end
  end
end
