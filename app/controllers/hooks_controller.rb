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

        # We don't get the right body structure.
        #
        unless payload_json = params[:payload]
          halt 422
        end

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

        head_commit_id = payload['head_commit']['id']

        # Go through each of the commits and get the commit data.
        #
        payload['commits'].each do |manual_commit|
          commit_sha = manual_commit['id']

          # Do not process merge commits.
          #
          next if head_commit_id == commit_sha && manual_commit['message'].start_with?('Merge pull request #')

          committer_email = manual_commit['committer']['email']
          committer_name = manual_commit['committer']['name']

          # Get all changed (added + modified) files.
          #
          # TODO: We ignore deleted specs.
          # https://github.com/CocoaPods/trunk.cocoapods.org/issues/46
          #
          {
            :added => manual_commit['added'],
            :modified => manual_commit['modified']
          }.each do |type, files|
            next if files.empty?
            Commit::Import.import(commit_sha, type, files, committer_email, committer_name)
          end
        end

        200
      end
    end
  end
end
