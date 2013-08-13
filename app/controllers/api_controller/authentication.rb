module Pod
  module TrunkApp
    class APIController
      module Authentication
        def find_authenticated_owner
          before do
            if @session = Session.with_token(authentication_token)
              @owner = @session.owner
            end
          end
        end
      end

      register Authentication
    end
  end
end
