module SpecHelpers
  module Authentication
    def create_session_with_owner
      @owner = Pod::TrunkApp::Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      session = Pod::TrunkApp::Session.new(:owner => @owner, :created_from_ip => '127.0.0.1')
      session.verified = true
      session.save
      session
    end

    def sign_in!
      session = create_session_with_owner
      header 'Authorization', "Token #{session.token}"
      session
    end
  end
end
