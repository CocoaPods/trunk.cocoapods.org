require 'app/controllers/api_controller'
require 'app/models/owner'
require 'app/models/session'

require 'active_support/core_ext/hash/slice'

module Pod
  module TrunkApp
    class SessionsController < APIController

      post '/', :requires_owner => false do
        owner_params = JSON.parse(request.body.read)
        # Savepoint is needed in testing, because tests already run in a
        # transaction, which means the transaction would be re-used and we
        # can't test whether or the transaction has been rolled back.
        DB.transaction(:savepoint => (settings.environment == :test)) do
          if owner = Owner.find_by_email(owner_params['email'])
            owner.update(:name => owner_params['name']) if owner_params['name']
          else
            owner = Owner.create(owner_params.slice('email', 'name'))
          end
          session = owner.create_session!(url('/sessions/verify/%s'))
          session_attributes = session.public_attributes
          session_attributes['token'] = session.token
          json_message(201, session_attributes)
        end
      end

      # TODO render HTML
      get '/verify/:token', :requires_owner => false do
        if session = Session.with_verification_token(params[:token])
          session.update(:verified => true)
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
          session.destroy unless session == @session
        end
        json_message(200, @session)
      end

    end
  end
end

