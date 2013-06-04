module Pod
  module PushApp
    class App
      module Authentication
        def find_authenticated_user
          before do
            @session = Session.with_token(authentication_token)
          end
        end
      end

      register Authentication
    end
  end
end
