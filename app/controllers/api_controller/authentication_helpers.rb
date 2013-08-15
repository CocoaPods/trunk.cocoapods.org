module Pod
  module TrunkApp
    class APIController
      module AuthenticationHelpers
        def owner?
          if @owner
            return true
          elsif authentication_token.blank?
            error(401, "Please supply an authentication token.".to_yaml)
          else
            error(401, "Authentication token is invalid or unverified.".to_yaml)
          end
          false
        end
      end

      helpers AuthenticationHelpers
    end
  end
end
