require 'app/controllers/app_controller'

require 'app/models/owner'
require 'app/models/pod'
require 'app/models/session'
require 'app/models/specification_wrapper'

module Pod
  module TrunkApp
    class HookController < AppController
      
      # --- Post Receive Hook -------------------------------------------------------------------
      
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
        manual_commits = payload['commits'].select { |commit| commit['message'] !~ /\A\[Add\]/ }
        
        # Go through each of the commits and get the commit data.
        #
        manual_commits.each do |manual_commit|
          commit_sha = manual_commit['id']
          
          # Get all changed (added + modified) files.
          #
          # TODO What to do with deleted podspecs?
          #
          changed_files = manual_commit['added'] + manual_commit['modified']
          
          # For each changed file, get its data (if it's a podspec).
          #
          # TODO Only get the latest version of a file.
          #
          changed_files.each do |changed_file|
            next unless changed_file =~ /\.podspec\z/ # TODO Use existing CP code for this.
            
            # Get the data from the Specs repo.
            #
            # TODO Move the template to a special class.
            # TODO Spec this so the test does not use the network.
            #
            data_url_template = "https://raw.github.com/CocoaPods/Specs/%s/%s"
            data_url = data_url_template % [commit_sha, changed_file] if commit_sha
            
            # Gets the data from data_url.
            #
            specification = REST.send(:get, data_url)
            
            # Update the database after extracting the relevant data from the podspec.
            #
            pod = Pod.find(name: specification.name)
            pod = if pod
              # The pod exists.
              #
              # TODO Possibly add a new version.
              #
              
            else
              # The pod does not exist.
              #
              # TODO Who is an owner?
              #
              Pod.create(:name => specification.name)
            end
          end
        end
        
        200
      end
      
    end
  end
end
