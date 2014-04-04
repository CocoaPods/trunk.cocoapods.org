require 'app/models/owner'

Pod::TrunkApp::Owner.create(:email => Pod::TrunkApp::Owner::UNCLAIMED_OWNER_EMAIL, :name => 'Unclaimed')
