require File.expand_path('../../spec_helper', __FILE__)
require 'nokogiri'

module Pod::TrunkApp
  describe ClaimsController, "when claiming pods" do
    def response_doc
      Nokogiri::HTML(last_response.body)
    end

    it "renders a new claim form" do
      get '/new'
      last_response.status.should == 200
      form = response_doc.css('form').first
      form['action'].should == '/claims'
      form['method'].should == 'POST'
    end

    it "does not create an owner if no pods are specified" do
      lambda {
        post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => []
      }.should.not.change { Owner.count }
      last_response.status.should == 200
      form = response_doc.css('form').first
      form.css('input[name="owner[email]"]').first['value'].should == 'appie@example.com'
      form.css('input[name="owner[name]"]').first['value'].should == 'Appie Duran'
    end

    before do
      unclaimed_owner = Owner.new(:email => Owner::UNCLAIMED_OWNER_EMAIL, :name => 'Unclaimed')
      # The email address doesn’t pass our mocked RFC822.mx_records(), so don't validate.
      unclaimed_owner.save(:validate => false)
      @pod = unclaimed_owner.add_pod(:name => 'AFNetworking')
    end

    it "creates an owner and assigns it to the claimed pods" do
      lambda {
        post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      }.should.change { Owner.count }
      owner = Owner.find_by_email('appie@example.com')
      owner.name.should == 'Appie Duran'
      @pod.reload.owners.should == [owner]
      last_response.location.should == 'https://example.org/thanks'
    end

    it "finds an existing owner and assigns it to the claimed pods" do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      lambda {
        post '/', :owner => { :email => 'appie@example.com' }, :pods => ['AFNetworking']
      }.should.not.change { Owner.count }
      @pod.reload.owners.should == [owner]
      last_response.location.should == 'https://example.org/thanks'
    end

    it "finds an existing owner and updates its name if specified" do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      post '/', :owner => { :email => 'appie@example.com', :name => ' ' }, :pods => ['AFNetworking']
      owner.reload.name.should == 'Appie Duran'
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appiepocalypse' }, :pods => ['AFNetworking']
      owner.reload.name.should == 'Appiepocalypse'
    end

    it "does not assign a pod that has already been claimed" do
      other_pod = Pod.create(:name => 'ObjectiveSugar')
      other_owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny')
      other_owner.add_pod(other_pod)
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking', 'ObjectiveSugar']
      owner = Owner.find_by_email('appie@example.com')
      @pod.reload.owners.should == [owner]
      other_pod.reload.owners.should == [other_owner]
      last_response.status.should == 302
      last_response.location.should == "https://example.org/dispute/new?#{{ 'claimer_email' => owner.email, 'pods' => ['ObjectiveSugar'] }.to_query}"
    end

    it "rolls back in case of an error" do
      Pod.any_instance.stubs(:remove_owner).raises
      lambda {
        should.raise do
          post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
        end
      }.should.not.change { Owner.count }
      @pod.reload.owners.should == [Owner.unclaimed]
    end

    it "shows validation errors" do
      post '/', :owner => { :email => 'appie@example.com', :name => '' }, :pods => ['AFNetworking', 'EYFNetworking', 'JAYSONKit']
      last_response.status.should == 200
      @pod.reload.owners.should == [Owner.unclaimed]
      errors = response_doc.css('.errors li')
      errors.first.text.should == 'Owner name is not present.'
      errors.last.text.should == 'Unknown Pods EYFNetworking and JAYSONKit.'
    end

    it "lists already claimed pods" do
      @pod.remove_owner(Owner.unclaimed)
      @pod.add_owner(Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny'))
      get '/dispute/new', :claimer_email => 'appie@example.com', :pods => ['AFNetworking']
      last_response.status.should == 200
      container = response_doc.css('article').first
      container.css('li').first.text.should == 'AFNetworking: jenny@example.com'
      form = container.css('form').first
      form.css('input[name="dispute[claimer_email]"]').first['value'].should == 'appie@example.com'
      form.css('textarea').first.text.should.include 'AFNetworking'
    end
  end
end
