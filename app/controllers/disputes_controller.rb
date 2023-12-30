require 'app/controllers/app_controller'
require 'app/models/dispute'
require 'app/controllers/slack_controller'

require 'active_support/core_ext/object/to_query'
require 'sinatra/twitter-bootstrap'
require 'slim'
require 'rest'

module Pod
  module TrunkApp
    class DisputesController < HTMLController
      configure do
        set :views, File.join(settings.root, 'app/views/disputes')
      end

      configure :development do
        register Sinatra::Reloader
      end

      def shared_partial(*sources)
        sources.inject([]) do |combined, source|
          combined << Slim::Template.new(File.join(settings.root, "shared/includes/_#{source}.slim"), {}).render
        end.join
      end

      get '/' do
        @pods = []
        @owner = Owner.new
        slim :index
      end

      get '/new' do
        @pods = params[:pods].map { |name| Pod.find_by_name(name) }
        @claimer_email = params[:claimer_email]
        slim :new
      end

      post '/new' do
        find_owner
        find_pods
        if @owner.valid? && valid_pods?
          query = {
            :claimer_email => @owner.email,
            :pods => @pods.map(&:name),
          }
          redirect to("new?#{query.to_query}")
        end
        prepare_errors
        slim :new
      end

      post '/' do
        claimer = Owner.find_by_email(params[:claimer_email])
        dispute = Dispute.create(:claimer => claimer, :message => params[:message])
        SlackController.notify_slack_of_new_dispute(dispute)
        redirect to('/thanks')
      end

      get '/thanks' do
        slim :thanks
      end

      private

      def find_owner
        owner_email, owner_name = params[:owner].values_at('email', 'name')
        @owner = Owner.find_or_initialize_by_email_and_name(owner_email, owner_name)
      end

      def find_pods
        @pods = []
        @invalid_pods = []
        unless params[:pods].blank?
          params[:pods].map(&:strip).uniq.each do |pod_name|
            next if pod_name.blank?

            if pod = Pod.find_by_name(pod_name)
              @pods << pod
            else
              @invalid_pods << pod_name
            end
          end
        end
      end

      def valid_pods?
        !@pods.empty? && @invalid_pods.empty?
      end

      def prepare_errors
        @errors = @owner.errors.full_messages.map { |message| "Owner #{message}." }
        if !@invalid_pods.empty?
          @errors << "Unknown #{'Pod'.pluralize(@invalid_pods.size)} #{@invalid_pods.to_sentence}."
        elsif @pods.empty?
          @errors << 'No Pods specified.'
        end
      end
    end
  end
end
