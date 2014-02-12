require 'app/controllers/app_controller'

require 'active_support/core_ext/object/to_query'
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
        find_owner
        find_pods
        if @owner.valid? && !@pods.empty? && @invalid_pods.empty?
          change_ownership
          if @already_claimed_pods.empty?
            redirect to('/thanks')
          else
            redirect to("/dispute?#{{ 'owner[email]' => @owner.email, 'pods' => @already_claimed_pods }.to_query}")
          end
        else
          prepare_errors
          slim :'new'
        end
      end

      private

      def find_owner
        owner_email, owner_name = params[:owner].values_at('email', 'name')
        @owner = Owner.find_or_initialize_by_email_and_update_name(owner_email, owner_name)
      end

      def find_pods
        @pods = []
        @invalid_pods = []
        unless params[:pods].blank?
          params[:pods].map(&:strip).uniq.each do |pod_name|
            next if pod_name.blank?
            if pod = Pod.find(:name => pod_name)
              @pods << pod
            else
              @invalid_pods << pod_name
            end
          end
        end
      end

      def prepare_errors
        @errors = @owner.errors.full_messages.map { |message| "Owner #{message}." }
        if !@invalid_pods.empty?
          @errors << "Unknown #{'Pod'.pluralize(@invalid_pods.size)} #{@invalid_pods.to_sentence}."
        elsif @pods.empty?
          @errors << 'No Pods specified.'
        end
      end

      def change_ownership
        @already_claimed_pods = []
        DB.test_safe_transaction do
          @owner.save_changes(:raise_on_save_failure => true)
          unclaimed_owner = Owner.unclaimed
          @pods.each do |pod|
            if pod.owners == [unclaimed_owner]
              @owner.add_pod(pod)
              pod.remove_owner(unclaimed_owner)
            else
              @already_claimed_pods << pod.name
            end
          end
        end
      end

    end
  end
end

