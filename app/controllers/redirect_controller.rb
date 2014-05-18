module Pod
  module TrunkApp
    class RedirectController < AppController

      get '/' do
        redirect to('/claims/new')
      end

    end
  end
end