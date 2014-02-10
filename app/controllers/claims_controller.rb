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
          # Savepoint is needed in testing, because tests already run in a
          # transaction, which means the transaction would be re-used and we
          # can't test whether or the transaction has been rolled back.
          DB.transaction(:savepoint => (settings.environment == :test)) do
            if owner = Owner.find_by_email(params[:owner]['email'])
              if (name = params[:owner]['name']) && !name.blank?
                owner.update(:name => params[:owner]['name'])
              end
            else
              owner = Owner.create(params[:owner].slice('email', 'name'))
            end
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

