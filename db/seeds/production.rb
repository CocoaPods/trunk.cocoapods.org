require 'app/models/owner'

module Pod::TrunkApp
  Owner.create(:email => 'eloy.de.enige@gmail.com', :name => 'Eloy Durán')

  Owner.create(:email => Owner::UNCLAIMED_OWNER_EMAIL, :name => 'Unclaimed')
end
