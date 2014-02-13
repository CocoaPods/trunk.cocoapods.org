require 'app/controllers/app_controller'

require 'app/models/owner'
require 'app/models/pod'
require 'app/models/session'
require 'app/models/specification_wrapper'

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
        manual_commits = payload['commits'].select { |commit| commit['message'] !~ /\A\[Add\]/ }
        
        # Go through each of the commits and get the commit data.
        #
        manual_commits.each do |manual_commit|
          commit_sha   = manual_commit['id']
          author_email = manual_commit['author']['email']
          author_name  = manual_commit['author']['name']
          
          # Get all changed (added + modified) files.
          #
          # Note: We ignore deleted specs.
          #
          changed_files = manual_commit['added'] + manual_commit['modified']
          
          # For each changed file, get its data (if it's a podspec).
          #
          # TODO Only get the latest version of a file.
          #
          changed_files.each do |changed_file|
            # TODO Use existing CP code for this?
            #
            next unless changed_file =~ /\.podspec.json\z/
            
            # Get the data from the Specs repo.
            #
            # TODO Update to the right repo.
            #
            data_url_template = "https://raw.github.com/alloy/trunk.cocoapods.org-test/%s/Specs/%s"
            data_url = data_url_template % [commit_sha, changed_file] if commit_sha
            
            # Gets the data from data_url.
            #
            spec_hash = JSON.parse REST.get(data_url).body
            
            # Update the database after extracting the relevant data from the podspec.
            #
            pod = Pod.find(name: spec_hash['name'])
            
            if pod
              version = PodVersion.find(:pod => pod, :name => spec_hash['version'])
              
              # We ignore any new pod versions coming in through a manual merge.
              #
              if version
                # Add a new commit to the existing version.
                #
                version.add_commit(
                  :pushed => true,
                  :sha => commit_sha,
                  :specification_data => JSON.pretty_generate(spec_hash)
                  # TODO What about an owner?
                )
              end
            end
          end
        end
        
        200
      end
      
    end
  end
end
