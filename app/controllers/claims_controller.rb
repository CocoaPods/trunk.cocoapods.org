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
        @owner = Owner.new
        @pods = []
        slim :'new'
      end

      post '/' do
        owner_email, owner_name = params[:owner].values_at('email', 'name')
        @owner = Owner.find_or_initialize_by_email_and_update_name(owner_email, owner_name)

        @pods = []
        invalid_pods = []
        unless params[:pods].blank?
          params[:pods].map(&:strip).uniq.each do |pod_name|
            next if pod_name.blank?
            if pod = Pod.find(:name => pod_name)
              @pods << pod
            else
              invalid_pods << pod_name
            end
          end
        end

        if @owner.valid? && !@pods.empty? && invalid_pods.empty?
          DB.test_safe_transaction do
            @owner.save_changes(:raise_on_save_failure => true)
            unclaimed_owner = Owner.unclaimed
            @pods.each do |pod|
              if pod.owners == [unclaimed_owner]
                @owner.add_pod(pod)
                pod.remove_owner(unclaimed_owner)
              end
            end
          end
          redirect to('/thanks')
        else
          @errors = @owner.errors.full_messages.map { |message| "Owner #{message}." }
          if !invalid_pods.empty?
            @errors << "Unknown #{'Pod'.pluralize(invalid_pods.size)} #{invalid_pods.to_sentence}."
          elsif @pods.empty?
            @errors << 'No Pods specified.'
          end
          slim :'new'
        end
      end

    end
  end
end

