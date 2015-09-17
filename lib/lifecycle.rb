module Pod
  
  # Provides an interface to .
  #
  class Lifecycle
    
    def initialize owner
      @owner = owner
    end
    
    # Add a specification.
    #
    def push!(specification)
      pod = Pod.find_by_name_and_owner(specification.name, @owner) do
        # TODO Move out.
        message = 'You are not allowed to push new versions for this pod.'
        json_error(403, message)
      end
      
      DB.transaction do
        if pod
          pod.update(:deleted => false) if pod.deleted?
        else
          pod = Pod.create(:name => specification.name)
        end
      
        # Add the owner.
        pod.add_owner(@owner)
      
        # 
        if version = pod.versions_dataset.where(:name => specification.version).first
          if version.published?
            headers 'Location' => url(version.resource_path)
            message = "Unable to accept duplicate entry for: #{specification}"
            json_error(409, message)
          end
        else
          version = pod.add_version(:name => specification.version)
        end
        
        potentially_undelete(pod, version)
        
        version.push!(@owner, specification.to_pretty_json)
      end
      
      def potentially_undelete(pod, version)
        version.update(:deleted => false)
        potentially_undelete_pod(pod)
      end
      
      def potentially_undelete_pod(pod)
        if pod.deleted?
          if pod.versions.count
        end
      end
    end
    
  end
  
end