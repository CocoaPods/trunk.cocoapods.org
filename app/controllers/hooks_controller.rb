require 'app/controllers/app_controller'

require 'app/models/owner'
require 'app/models/pod'
require 'app/models/session'
require 'app/models/specification_wrapper'

# TODO
# Add logging to all steps and include as its LogMessage#reference:
#
#     "GitHub hook with temporary ID: #{object_id}"
#
module Pod
  module TrunkApp
    class HooksController < AppController

      # --- Post Receive Hook ---------------------------------------------------------------------

      # TODO Package most of this action's content neatly into
      # a class specific to loading podspec data.
      #
      post "/github-post-receive/#{ENV['HOOK_PATH']}" do
        halt 415 unless request.media_type == 'application/x-www-form-urlencoded'

        payload_json = params[:payload]

        # We don't get the right body structure.
        #
        halt 422 unless payload_json

        payload = nil
        begin
          payload = JSON.parse(payload_json)
        rescue JSON::ParserError
          # The payload is not JSON.
          #
          halt 415
        end

        # The payload structure is not correct.
        #
        return 422 unless payload.respond_to?(:to_h)

        # Select commits not made by ourselves.
        #
        # No, we even look at our own commits.
        #
        # manual_commits = payload['commits'].select { |commit| commit['message'] !~ /\A\[Add\]/ }

        # Go through each of the commits and get the commit data.
        #
        payload['commits'].each do |manual_commit|
          commit_sha   = manual_commit['id']
          committer_email = manual_commit['committer']['email']

          # Get all changed (added + modified) files.
          #
          # Note: We ignore deleted specs.
          #
          {
            :added => manual_commit['added'] || [],
            :modified => manual_commit['modified'] || []
          }.each do |type, files|

            # For each changed file, get its data (if it's a podspec).
            #
            # TODO Only get the latest version of a file.
            #
            files.each do |file|
              # TODO Add .podspec example.
              #
              next unless file =~ /\.podspec(.json)?\z/

              # Get the data from the Specs repo.
              #
              # TODO Update to the right repo.
              #
              data_url_template = "https://raw.github.com/alloy/trunk.cocoapods.org-test/%s/Specs/%s"
              data_url = data_url_template % [commit_sha, file] if commit_sha

              # Gets the data from data_url.
              #
              spec = ::Pod::Specification.from_string(REST.get(data_url).body, file)

              # Update the database after extracting the relevant data from the podspec.
              #
              pod = Pod.find(name: spec.name)

              send :"handle_#{type}", spec, pod, commit_sha, committer_email if pod
            end
          end
        end

        200
      end

      # We get the JSON podspec and add a commit to the pod's version (And
      # add a new version if necessary).
      #
      def handle_modified spec, pod, commit_sha, committer_email
        committer = pod.owners_dataset.first(:email => committer_email) || Owner.unclaimed

        version_name = spec.version.to_s

        # Note: Sadly, we cannot use find_or_create here.
        #
        version = PodVersion.find(:pod => pod, :name => version_name)
        unless version
          version = PodVersion.create(:pod => pod, :name => version_name)
          version.add_log_message(
            :reference => "Github hook call to temporary ID: #{object_id}",
            :level => :warning,
            :message => "Version `#{version.description}' created via Github hook.",
            :owner => committer
          )
        end

        # Add a new commit to the existing version.
        #
        version.add_commit(
          :sha => commit_sha,
          :specification_data => JSON.pretty_generate(spec.attributes_hash),
          :committer => committer,
        )
      end

      # We only check if we have it, and if not, add it.
      #
      def handle_added spec, pod, commit_sha, committer_email
        # Do we have it?
        #
        if commit = Commit.find(:sha => commit_sha)
          # Is it related to the pod?
          #
          unless commit.pod_version.pod == pod
            # TODO It's not. Log as error?
            #
          end
        else
          # No? We should create it and connect it to the pod.
          #
          # TODO What if the version does not exist yet? Should we add one?
          #
          handle_modified spec, pod, commit_sha, committer_email
        end
      end

    end
  end
end
