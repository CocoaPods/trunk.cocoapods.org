module Pod
  module TrunkApp
    class RedirectController < AppController
      get '/' do
        redirect to('/claims/new')
      end

      not_found do
        slim :'not_found', :status => 404
      end
    end
  end
end
