require File.expand_path('../spec_helper', __dir__)

module Pod::TrunkApp
  describe ClaimsController, 'when claiming pods' do
    seed_unclaimed

    it 'renders a new claim form' do
      get '/new'
      last_response.status.should == 200
      form = response_doc.css('form').first
      form['action'].should == '/claims'
      form['method'].should == 'POST'
    end

    it 'does not create an owner if no pods are specified' do
      lambda do
        post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => []
      end.should.not.change { Owner.count }
      last_response.status.should == 200
      form = response_doc.css('form').first
      form.css('input[name="owner[email]"]').first['value'].should == 'appie@example.com'
      form.css('input[name="owner[name]"]').first['value'].should == 'Appie Duran'
    end

    before do
      @pod = Owner.unclaimed.add_pod(:name => 'AFNetworking')
    end

    it 'creates an owner and assigns it to the claimed pods' do
      lambda do
        post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      end.should.change { Owner.count }
      owner = Owner.find_by_email('appie@example.com')
      owner.name.should == 'Appie Duran'
      @pod.reload.owners.should == [owner]
    end

    it 'finds an existing owner and assigns it to the claimed pods' do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      lambda do
        post '/', :owner => { :email => 'appie@example.com' }, :pods => ['AFNetworking']
      end.should.not.change { Owner.count }
      @pod.reload.owners.should == [owner]
    end

    it "finds an existing owner and doesn't update its name" do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appiepocalypse' }, :pods => ['AFNetworking']
      owner.reload.name.should == 'Appie Duran'
    end

    it 'does not assign a pod that has already been claimed' do
      other_pod = Pod.create(:name => 'ObjectiveSugar')
      other_owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny')
      other_owner.add_pod(other_pod)
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' },
                :pods => %w[AFNetworking ObjectiveSugar]
      owner = Owner.find_by_email('appie@example.com')
      @pod.reload.owners.should == [owner]
      other_pod.reload.owners.should == [other_owner]
      last_response.status.should == 302
      query = { :claimer_email => owner.email, :successfully_claimed => ['AFNetworking'],
                :already_claimed => ['ObjectiveSugar'] }
      last_response.location.should == "https://example.org/thanks?#{query.to_query}"
    end

    it 'immediately redirects to the dispute page if all pods are claimed' do
      @pod.remove_owner(Owner.unclaimed)
      owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny')
      owner.add_pod(@pod)
      lambda do
        post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      end.should.change { Owner.count }
      last_response.status.should == 302
      uri = URI.parse(last_response.location)
      uri.path.should == '/disputes/new'
      query = { 'claimer_email' => 'appie@example.com', 'pods[]' => 'AFNetworking' }
      Rack::Utils.parse_query(uri.query).should == query
      Owner.find_by_email('appie@example.com').should.not.be.nil
    end

    it 'rolls back in case of an error' do
      Pod.any_instance.stubs(:remove_owner).raises
      lambda do
        should.raise do
          post('/',
               :owner => {
                 :email => 'appie@example.com',
                 :name => 'Appie Duran',
               },
               :pods => ['AFNetworking'])
        end
      end.should.not.change { Owner.count }
      @pod.reload.owners.should == [Owner.unclaimed]
    end

    it 'shows validation errors' do
      post('/',
           :owner => { :email => 'appie@example.com', :name => '' },
           :pods => %w[AFNetworking EYFNetworking JAYSONKit])
      last_response.status.should == 200
      @pod.reload.owners.should == [Owner.unclaimed]
      errors = response_doc.css('.errors li')
      errors.first.text.should == 'Owner name is not present.'
      errors.last.text.should == 'Unknown Pods EYFNetworking and JAYSONKit.'
    end

    it 'shows a thanks page' do
      get('/thanks',
          :claimer_email => 'appie@example.com',
          :successfully_claimed => ['AFNetworking'],
          :already_claimed => ['JSONKit'])
      last_response.status.should == 200
      last_response.body.should.include 'AFNetworking'
      last_response.body.should.include 'JSONKit'

      link = response_doc.css('article p a')[2]
      query = { :claimer_email => 'appie@example.com', :pods => ['JSONKit'] }
      link['href'].should == "https://example.org/disputes/new?#{query.to_query}"
    end
  end

  describe ClaimsController, 'concerning disputes' do
    before do
      @owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny')
      @pod = @owner.add_pod(:name => 'AFNetworking')
    end

    it 'lists already claimed pods' do
      get '/disputes/new', :claimer_email => 'appie@example.com', :pods => ['AFNetworking']
      last_response.status.should == 200
      container = response_doc.css('article').first
      container.css('li').first.text.should == 'AFNetworking <jenny@example.com>'
      form = container.css('form').first
      form.css('input[name="dispute[claimer_email]"]').first['value'].should == 'appie@example.com'
      form.css('textarea').first.text.should.include 'AFNetworking'
    end

    it 'creates a new dispute' do
      lambda do
        post '/disputes', :dispute => { :claimer_email => @owner.email, :message => 'GIMME!' }
      end.should.change { Dispute.count }
      last_response.location.should == 'https://example.org/disputes/thanks'
      dispute = Dispute.last
      dispute.claimer.should == @owner
      dispute.message.should == 'GIMME!'
      dispute.should.not.be.settled
    end

    it 'shows a thanks page' do
      get '/disputes/thanks'
      last_response.status.should == 200
    end
  end
end
