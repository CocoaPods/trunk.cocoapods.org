require 'app/controllers/app_controller'

require 'app/models/owner'
require 'app/models/pod'
require 'app/models/session'
require 'app/models/specification_wrapper'

module Pod
  module TrunkApp
    class HookController < AppController
      
      # --- Post Receive Hook -------------------------------------------------------------------
      
      # TODO Return good errors.
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
        
        manual_commits = payload['commits'].select { |commit| commit['message'] !~ /\A\[Add\]/ }
        
        manual_commits.each do |manual_commit|
          commit_sha = manual_commit['id']
          manual_commit['modified'].each do |modified_file|
            # github = GitHub.new(ENV['GH_REPO'], :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic')
            
            # data_url_template = "https://raw.github.com/#{ENV['GH_REPO']}/%s/%s"
            data_url_template = "https://raw.github.com/alloy/trunk.cocoapods.org-test/%s/%s"
            data_url = data_url_template % [commit_sha, modified_file] if commit_sha
            
            puts
            puts data_url
            
            # TODO Get the data from data_url here and update the database.
          end
        end
        
        200
      end
      
    end
  end
end
