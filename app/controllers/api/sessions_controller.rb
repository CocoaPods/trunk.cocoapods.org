require 'app/controllers/api_controller'
require 'app/models/owner'
require 'app/models/session'

require 'active_support/core_ext/hash/slice'

module Pod
  module TrunkApp
    class SessionsController < APIController
      post '/', :requires_owner => false do
        owner_params = JSON.parse(request.body.read)
        authorized = @owner.present?

        DB.test_safe_transaction do
          owner_email, owner_name, session_description = owner_params.values_at('email', 'name', 'description')
          owner = Owner.find_or_initialize_by_email_and_name(owner_email, owner_name).tap do |o|
            o.name = owner_name if authorized && owner_name.present?
            o.save
          end

          url_template = ENV['RACK_ENV'] == 'test' ? "#{request.scheme}://#{request.host_with_port}/sessions/verify/%s" : 'https://trunk.cocoapods.org/sessions/verify/%s'
          session = owner.create_session!(request.ip, url_template, session_description)
          session_attributes = session.public_attributes
          session_attributes['token'] = session.token

          json_message(201, session_attributes)
        end
      end

      get '/verify/:token', :requires_owner => false do
        if session = Session.with_verification_token(params[:token])
          session.verify!
          json_message(200, session)
        else
          json_error(404, 'Session not found.')
        end
      end

      get '/', :requires_owner => true do
        owner_attributes = @owner.public_attributes
        owner_attributes['sessions'] = @owner.sessions.map do |session|
          attrs = session.public_attributes
          attrs[:current] = session.id == @session.id
          attrs
        end
        json_message(200, owner_attributes)
      end

      delete '/', :requires_owner => true do
        sessions_except_current.each do |session|
          next if session.active?

          session.destroy
        end
        json_message(200, @session)
      end

      delete '/all', :requires_owner => true do
        sessions_except_current.each(&:destroy)
        json_message(200, @session)
      end

      private

      def sessions_except_current
        @owner.sessions.reject do |session|
          session.id == @session.id
        end
      end
    end
  end
end
