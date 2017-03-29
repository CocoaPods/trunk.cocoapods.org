require 'app/models/owner'

module Pod
  module TrunkApp
    # This is an insider attribution to those that have worked on the initial app.
    Owner.find_or_create(:email => 'eloy.de.enige@gmail.com', :name => 'Eloy Durán')
    Owner.find_or_create(:email => 'florian.hanke@gmail.com', :name => 'Florian R. Hanke')
    Owner.find_or_create(:email => 'manfred@fngtps.com',      :name => 'Manfred Stienstra')
    Owner.find_or_create(:email => 'orta.therox@gmail.com',   :name => 'Orta Therox')
    Owner.find_or_create(:email => 'inbox@kylefuller.co.uk',  :name => 'Kyle Fuller')
    Owner.find_or_create(:email => 'fabiopelosin@gmail.com',  :name => 'Fabio Pelosin')

    Owner.find_or_create(:email => Owner::UNCLAIMED_OWNER_EMAIL, :name => 'Unclaimed')
  end
end
