module SpecHelpers
  module Authentication
    def create_session_with_owner
      owner = Pod::PushApp::Owner.create
      session = Pod::PushApp::Session.create
      owner.add_session(session)
      session
    end
  end
end