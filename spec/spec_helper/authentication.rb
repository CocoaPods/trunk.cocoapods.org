module SpecHelpers
  module Authentication
    def create_session_with_owner
      owner = Pod::TrunkApp::Owner.create
      session = Pod::TrunkApp::Session.create
      owner.add_session(session)
      session
    end
  end
end
