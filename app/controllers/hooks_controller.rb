require 'app/controllers/app_controller'

require 'app/models/owner'
require 'app/models/pod'
require 'app/models/session'
require 'app/models/specification_wrapper'
require 'app/models/commit/import'

module Pod
  module TrunkApp
    class HooksController < AppController
      # --- Post Receive Hook ---------------------------------------------------------------------

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
            :added => manual_commit['added'],
            :modified => manual_commit['modified']
          }.each do |type, files|
            Commit::Import.import(commit_sha, committer_email, type, files || [])
          end
        end

        200
      end
    end
  end
end
