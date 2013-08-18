require 'app/controllers/app_controller'

require 'app/models/owner'
require 'app/models/pod'
require 'app/models/session'
require 'app/models/specification_wrapper'

require 'active_support/core_ext/hash/slice'

module Pod
  module TrunkApp
    class APIController < AppController
      require 'app/controllers/api_controller/yaml_request_response'
      require 'app/controllers/api_controller/authentication'

      find_authenticated_owner '/me', '/sessions', '/pods'

      # --- Sessions ------------------------------------------------------------------------------

      get '/me' do
        if owner?
          yaml_message(200, @owner)
        end
      end

      post '/register' do
        owner_params = YAML.load(request.body.read)
        if !owner_params.kind_of?(Hash) || owner_params.empty?
          yaml_error(422, 'Please send the owner email address in the body of your post.')
        else
          owner = Owner.find_by_email(owner_params['email']) || Owner.create(owner_params.slice('email', 'name'))
          session = owner.create_session!(url('/sessions/verify/%s'))
          yaml_message(201, session)
        end
      end

      # TODO render HTML
      get '/sessions/verify/:token' do
        if session = Session.with_verification_token(params[:token])
          session.update(:verified => true)
          yaml_message(200, session)
        else
          yaml_error(404, 'Session not found.')
        end
      end

      get '/sessions' do
        if owner?
          yaml_message(200, @owner.sessions.map(&:public_attributes))
        end
      end

      delete '/sessions' do
        if owner?
          @owner.sessions.each do |session|
            session.destroy unless session == @session
          end
          yaml_message(200, @session)
        end
      end

      # --- Pods ----------------------------------------------------------------------------------

      post '/pods' do
        if owner?
          specification = SpecificationWrapper.from_yaml(request.body.read)

          if specification.nil?
            yaml_error(400, 'Unable to load a Pod Specification from the provided input.')
          end

          unless specification.valid?
            yaml_error(422, specification.validation_errors)
          end

          unless pod = Pod.find_by_name_and_owner(specification.name, @owner)
            yaml_error(403, 'You are not allowed to push new versions for this pod.')
          end

          # Always set the location of the resource, even when the pod version already exists.
          resource_url = url("/pods/#{specification.name}/versions/#{specification.version}")
          headers 'Location' => resource_url

          # TODO use a unique index in the DB for this instead?
          if pod.versions_dataset.where(:name => specification.version).first
            yaml_error(409, "Unable to accept duplicate entry for: #{specification}")
          end
          version = pod.add_version(:name => specification.version, :url => resource_url)
          version.add_submission_job(:specification_data => specification.to_yaml)
          halt 202
        end
      end

      get '/pods/:name/versions/:version' do
        if pod = Pod.find(:name => params[:name])
          if version = pod.versions_dataset.where(:name => params[:version]).first
            job = version.submission_jobs.last
            messages = job.log_messages.map do |log_message|
              { log_message.created_at => log_message.message }
            end
            # Would have preferred to use 102 instead of 202, but Ruby’s Net::HTTP apperantly does
            # not read the body of a 102 and so the client might have problems reporting status.
            status = job.failed? ? 404 : (version.published? ? 200 : 202)
            yaml_message(status, messages)
          end
        end
        error 404
      end
    end
  end
end
