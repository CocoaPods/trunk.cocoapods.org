require 'app/controllers/api_controller'
require 'app/models/deprecate_job'
require 'app/models/owner'
require 'app/models/pod'
require 'app/models/specification_wrapper'
require 'cocoapods-core/version'

module Pod
  module TrunkApp
    class PodsController < APIController
      MINIMUM_COCOAPODS_VERSION = Version.new(ENV.fetch('TRUNK_MINIMUM_COCOAPODS_VERSION') { '1.0.0' }.dup)

      def verify_github_responses!(responses)
        responses = Array(responses)
        responses.all? do |response|
          if response.success?
            true
          elsif response.failed_on_our_side?
            throw_internal_server_error!
          elsif response.failed_on_their_side?
            # In case of a 5xx at GitHub’s side, this might not mean the commit
            # didn’t get created, it can also indicate an error occurred while
            # rendering the response, hence asking for some patience in case we
            # still update the PodVersion with a new Commit from the GitHub
            # post-commit hook.
            #
            # TODO: Ask GitHub if they have some form of transaction system in
            # place that rolls back a commit in case an error occurs during
            # response rendering.
            json_error(500, 'An error occurred on GitHub’s side. Please check GitHub’s status at ' \
                            'https://status.github.com and try again later in case the pod is ' \
                            'still not published.')
          elsif response.failed_due_to_timeout?
            json_error(504, 'Calling the GitHub commit API timed out. Please check GitHub’s ' \
                            'status at https://status.github.com and try again later.')
          end
        end
      end

      def verify_pushes_allowed!
        if ENV['TRUNK_APP_PUSH_ALLOWED'] != 'true' && ENV['TRUNK_PUSH_ALLOW_OWNER_ID'].to_i != @owner.id
          json_error(503, 'We have closed pushing to CocoaPods trunk' \
                          ', please see https://twitter.com/CocoaPods for details')
        end
      end

      get '/:name', :requires_owner => false do
        if pod = Pod.find_by_name(params[:name])
          versions = pod.versions.select(&:published?)
          unless versions.empty?
            json_message(200, 'versions' => versions.map(&:public_attributes),
                              'owners'   => pod.owners.map(&:public_attributes))
          end
        end
        json_error(404, 'No pod found with the specified name.')
      end

      get '/:name/versions/:version', :requires_owner => false do
        if pod = Pod.find_by_name(params[:name])
          if version = pod.versions_dataset.where(:name => params[:version]).first
            if version.published?
              json_message(200, 'messages' => version.log_messages.map(&:public_attributes),
                                'data_url' => version.data_url)
            end
          end
        end
        json_error(404, 'No pod found with the specified version.')
      end

      get '/:name/specs/latest', :requires_owner => false do
        commits = DB[<<-SQL, params[:name]].all
          SELECT DISTINCT ON (pod_versions.id)
              pods.name          "name",
              pod_versions.name  "version",
              commits.sha        "sha",
              commits.created_at "created_at"
          FROM
              pods
          LEFT JOIN
              pod_versions ON pods.id = pod_versions.pod_id
          INNER JOIN
              commits      ON pod_versions.id = commits.pod_version_id
          WHERE
              pods.name = ? AND pods.deleted is false AND pod_versions.deleted is false
          ORDER BY
              pod_versions.id
        SQL
        if commit = commits.max_by { |c| Version.new(c[:version]) }
          path = PodVersion.destination_path(commit[:name], commit[:version], commit[:created_at])
          redirect format(PodVersion::DATA_URL, commit[:sha], path)
        end
        json_error(404, 'No pod found with the specified name.')
      end

      get '/:name/specs/:version', :requires_owner => false do
        if pod = Pod.find_by_name(params[:name])
          if version = pod.versions_dataset.where(:name => params[:version]).first
            if version.published?
              redirect version.data_url
            end
          end
        end
        json_error(404, 'No pod found with the specified name and version.')
      end

      post '/', :requires_owner => true do
        verify_pushes_allowed!

        if version = %r{CocoaPods/([0-9a-z\.]+)}i.match(env['User-Agent'])
          if Version.new(version[1]) < MINIMUM_COCOAPODS_VERSION
            message = 'The minimum CocoaPods version allowed to push new ' \
                      "specs is `#{MINIMUM_COCOAPODS_VERSION}`. Please update " \
                      'your version of CocoaPods to push this specification.'
            json_error(422, message)
          end
        end

        specification = SpecificationWrapper.from_json(request.body.read)
        if specification.nil?
          message = 'Unable to load a Pod Specification from the provided input.'
          json_error(400, message)
        end

        unless specification.publicly_accessible?
          json_error(403, 'Source code for your Pod was not accessible to' \
          ' CocoaPods Trunk. Is it a private repo or behind a username/password on http?')
        end

        allow_warnings = params['allow_warnings'] == 'true'
        unless specification.valid?(:allow_warnings => allow_warnings)
          message = 'The Pod Specification did not pass validation.'
          data = specification.validation_errors(:allow_warnings => allow_warnings)
          error(422, { 'error' => message, 'data' => data }.to_json)
        end

        pod = Pod.find_by_name_and_owner(specification.name, @owner, :include_deleted => true) do |unowned_pod|
          message = "You (#{@owner.email}) are not allowed to push new versions " \
                    "for this pod. The owners of this pod are #{unowned_pod.owners.map(&:email).to_sentence}."
          json_error(403, message)
        end

        version = nil

        # TODO: Move this code into a call akin to
        #   lifecycle = Pod::Lifecycle.new
        #   lifecycle.handle(@owner, specification)
        # And also move the
        #   version.push!(@owner, specification.to_pretty_json)
        # bit below into it.
        #
        # Then centrally and explicitly define all pod/version/commit
        # deleted etc. transitions in the "Lifecycle".
        DB.transaction do
          unless pod
            pod = Pod.create(:name => specification.name)
            pod.add_owner(@owner)
          end

          if version = pod.versions_dataset.where(:name => specification.version).first
            if version.published?
              headers 'Location' => url(version.resource_path)
              message = "Unable to accept duplicate entry for: #{specification}"
              json_error(409, message)
            end
          else
            version = pod.add_version(:name => specification.version)
          end
        end

        response = version.push!(@owner, specification.to_pretty_json, 'Add')
        redirect url(version.resource_path) if verify_github_responses!(response)
      end

      patch '/:name/deprecated', :requires_owner => true do
        verify_pushes_allowed!

        pod = Pod.find_by_name_and_owner(params[:name], @owner) do
          json_error(403, 'You are not allowed to deprecate this pod.')
        end
        unless pod
          json_error(404, 'No pod found with the specified name.')
        end

        deprecated_params = JSON.parse(request.body.read)
        if !deprecated_params.is_a?(Hash) || deprecated_params.empty?
          message = 'Please send the deprecation in the body of your post.'
          json_error(422, message)
        end

        if in_favor_of = deprecated_params['in_favor_of']
          unless Pod.find_by_name(Specification.root_name in_favor_of)
            json_error(422, 'You cannot deprecate a pod in favor of a pod that does not exist.')
          end
        end

        responses = DeprecateJob.new(pod, @owner, in_favor_of).deprecate!
        unless responses.any?
          json_error(422, 'There were no published versions to deprecate.')
        end

        redirect pod.versions.last.resource_path if verify_github_responses!(responses)
      end

      delete '/:name/:version', :requires_owner => true do
        verify_pushes_allowed!

        pod = Pod.find_by_name_and_owner(params[:name], @owner) do
          json_error(403, 'You are not allowed to delete this pod.')
        end
        unless pod
          json_error(404, 'No pod found with the specified name.')
        end

        version = pod.versions_dataset.where(:name => params[:version]).first
        unless version
          json_error(404, 'No pod version found with the specified version.')
        end
        if version.deleted?
          json_error(422, 'The version is already deleted.')
        end

        response = version.delete!(@owner)
        redirect version.resource_path if verify_github_responses!(response)
      end

      patch '/:name/owners', :requires_owner => true do
        pod = Pod.find_by_name_and_owner(params[:name], @owner) do
          json_error(403, 'You are not allowed to add owners to this pod.')
        end
        unless pod
          json_error(404, 'No pod found with the specified name.')
        end

        owner_params = JSON.parse(request.body.read)
        if !owner_params.is_a?(Hash) || owner_params.empty?
          message = 'Please send the owner email address in the body of your post.'
          json_error(422, message)
        end

        unless other_owner = Owner.find_by_email(owner_params['email'])
          json_error(404, 'No owner found with the specified email address.')
        end

        unless pod.owners.include?(other_owner)
          pod.add_owner(other_owner)
        end

        json_message(200, pod.owners.map(&:public_attributes))
      end

      delete '/:name/owners/:email', :requires_owner => true do
        pod = Pod.find_by_name_and_owner(params[:name], @owner) do
          json_error(403, 'You are not allowed to remove owners from this pod.')
        end
        unless pod
          json_error(404, 'No pod found with the specified name.')
        end

        unless other_owner = Owner.find_by_email(params[:email])
          json_error(404, 'No owner found with the specified email address.')
        end

        unless pod.owners.include?(other_owner)
          json_error(404, 'The owner with the specified email does not own this pod.')
        end

        pod.remove_owner(other_owner)
        pod.add_owner(Owner.unclaimed) if pod.owners.empty?

        json_message(200, pod.owners.map(&:public_attributes))
      end
    end
  end
end
