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

      get '/new' do
        slim :'new'
      end

      post '/' do
        if params[:pods].blank?
          slim :'new'
        else
          DB.test_safe_transaction do
            owner_email, owner_name = params[:owner].values_at('email', 'name')
            owner = Owner.find_or_create_by_email_and_update_name(owner_email, owner_name)
            unclaimed_owner = Owner.unclaimed
            params[:pods].each do |pod_name|
              pod = Pod.find(:name => pod_name)
              if pod.owners == [unclaimed_owner]
                owner.add_pod(pod)
                pod.remove_owner(unclaimed_owner)
              end
            end
            redirect to('/thanks')
          end
        end
      end

    end
  end
end

