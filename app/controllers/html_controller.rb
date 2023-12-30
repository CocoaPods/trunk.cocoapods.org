require 'app/controllers/app_controller'

module Pod
  module TrunkApp
    # Parent controller for all HTML serving controllers.
    #
    class HTMLController < AppController
      configure :development do
        register Sinatra::Reloader
      end

      get '/' do
        redirect to('/disputes/')
      end

      def shared_partial(*sources)
        sources.inject([]) do |combined, source|
          combined << Slim::Template.new("shared/includes/_#{source}.slim", {}).render
        end.join
      end

      # TODO: Handle this correctly.
      # Note: As settings.views is set in child
      # controllers, the not_found is not found here,
      # as the not_found is executed in the original
      # controller's context.
      # (-> setting settings.views here does not help)
      #
      not_found do
        slim :'../html/not_found', :status => 404, :layout => :'../html/layout'
      rescue Errno::ENOENT
        slim :'html/not_found', :status => 404, :layout => :'html/layout'
      end
    end
  end
end
