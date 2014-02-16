require 'app/controllers/api_controller'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/specification_wrapper'

module Pod
  module TrunkApp
    class PodsController < APIController

      get '/:name', :requires_owner => false do
        if pod = Pod.find(:name => params[:name])
          versions = pod.versions.select(&:published?)
          unless versions.empty?
            json_message(200, 'versions' => versions.map(&:public_attributes),
                              'owners'   => pod.owners.map(&:public_attributes))
          end
        end
        json_error(404, 'No pod found with the specified name.')
      end

      get '/:name/versions/:version', :requires_owner => false do
        if pod = Pod.find(:name => params[:name])
          if version = pod.versions_dataset.where(:name => params[:version]).first
            if version.published?
              commit = version.last_published_by
              job = commit.pushed_by
              json_message(200, 'messages' => job.log_messages.map(&:public_attributes),
                                'data_url' => version.data_url)
            end
          end
        end
        json_error(404, 'No pod found with the specified version.')
      end

      post '/', :requires_owner => true do
        unless ENV['TRUNK_APP_PUSH_ALLOWED'] == 'true'
          json_error(503, 'Push access is currently disabled.')
        end

        specification = SpecificationWrapper.from_json(request.body.read)
        if specification.nil?
          json_error(400, 'Unable to load a Pod Specification from the provided input.')
        end
        unless specification.valid?
          json_error(422, specification.validation_errors)
        end

        pod = Pod.find_by_name_and_owner(specification.name, @owner) do
          json_error(403, 'You are not allowed to push new versions for this pod.')
        end
        unless pod
          pod = Pod.create(:name => specification.name)
        end

        # TODO use a unique index in the DB for this instead?
        if version = pod.versions_dataset.where(:name => specification.version).first
          if version.published? || version.commits.any?(&:in_progress?)
            headers 'Location' => url(version.resource_path)
            json_error(409, "Unable to accept duplicate entry for: #{specification}")
          end
        else
          version = pod.add_version(:name => specification.version)
        end

        version.push!(@owner, JSON.pretty_generate(specification))
        redirect url(version.resource_path)
      end

      patch '/:name/owners', :requires_owner => true do
        pod = Pod.find_by_name_and_owner(params[:name], @owner) do
          json_error(403, 'You are not allowed to add owners to this pod.')
        end
        unless pod
          json_error(404, 'No pod found with the specified name.')
        end

        owner_params = JSON.parse(request.body.read)
        if !owner_params.kind_of?(Hash) || owner_params.empty?
          json_error(422, 'Please send the owner email address in the body of your post.')
        end

        unless other_owner = Owner.find_by_email(owner_params['email'])
          json_error(404, 'No owner found with the specified email address.')
        end

        pod.add_owner(other_owner)
        json_message(200, pod.owners.map(&:public_attributes))
      end

    end
  end
end
