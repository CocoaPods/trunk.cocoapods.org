require 'app/controllers/api_controller'
require 'app/models/owner'
require 'app/models/session'

require 'active_support/core_ext/hash/slice'

module Pod
  module TrunkApp
    class SessionsController < APIController
      post '/', :requires_owner => false do
        owner_params = JSON.parse(request.body.read)
        DB.test_safe_transaction do
          owner_email, owner_name = owner_params.values_at('email', 'name')
          owner = Owner.find_or_create_by_email_and_update_name(owner_email, owner_name)
          session = owner.create_session!(url('/sessions/verify/%s'))
          session_attributes = session.public_attributes
          session_attributes['token'] = session.token
          json_message(201, session_attributes)
        end
      end

      # TODO: render HTML
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
        owner_attributes['sessions'] = @owner.sessions.map(&:public_attributes)
        json_message(200, owner_attributes)
      end

      delete '/', :requires_owner => true do
        @owner.sessions.each do |session|
          next if session.id == @session.id
          session.destroy
        end
        json_message(200, @session)
      end
    end
  end
end
