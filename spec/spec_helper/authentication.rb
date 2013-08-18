module SpecHelpers
  module Authentication
    def create_session_with_owner
      @owner = Pod::TrunkApp::Owner.create(:email => 'appie@example.com')
      @owner.add_session(:verified => true)
    end

    def sign_in!
      session = create_session_with_owner
      header 'Authorization', "Token #{session.token}"
      session
    end
  end
end
