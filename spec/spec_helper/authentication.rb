module SpecHelpers
  module Authentication
    def create_session_with_owner
      owner = Pod::TrunkApp::Owner.create(:email => 'appie@example.com')
      session = Pod::TrunkApp::Session.create
      owner.add_session(session)
      session
    end

    def sign_in!
      session = create_session_with_owner
      header 'Authorization', "Token #{session.token}"
      session
    end
  end
end
