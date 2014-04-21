require 'app/models/owner'

module Pod
  module TrunkApp
    # This is an insider attribution to those that have worked on the initial app.
    Owner.create(:email => 'eloy.de.enige@gmail.com', :name => 'Eloy Durán')
    Owner.create(:email => 'florian.hanke@gmail.com', :name => 'Florian R. Hanke')
    Owner.create(:email => 'manfred@fngtps.com',      :name => 'Manfred Stienstra')
    Owner.create(:email => 'orta.therox@gmail.com',   :name => 'Orta Therox')
    Owner.create(:email => 'inbox@kylefuller.co.uk',  :name => 'Kyle Fuller')
    Owner.create(:email => 'fabiopelosin@gmail.com',  :name => 'Fabio Pelosin')

    Owner.create(:email => Owner::UNCLAIMED_OWNER_EMAIL, :name => 'Unclaimed')
  end
end
