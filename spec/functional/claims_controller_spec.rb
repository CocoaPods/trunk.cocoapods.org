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
    end

    it "finds an existing owner and assigns it to the claimed pods" do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      lambda {
        post '/', :owner => { :email => 'appie@example.com' }, :pods => ['AFNetworking']
      }.should.not.change { Owner.count }
      @pod.reload.owners.should == [owner]
    end

    it "finds an existing owner and updates its name if specified" do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      post '/', :owner => { :email => 'appie@example.com', :name => ' ' }, :pods => ['AFNetworking']
      owner.reload.name.should == 'Appie Duran'
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appiepocalypse' }, :pods => ['AFNetworking']
      owner.reload.name.should == 'Appiepocalypse'
    end

    it "does not assign a pod that has already been claimed" do
      other_owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny')
      other_owner.add_pod(@pod)
      @pod.remove_owner(Owner.unclaimed)
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      @pod.reload.owners.should == [other_owner]
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
    end

    it "redirects to the thanks page after successfully assigning pods" do
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      last_response.location.should == 'https://example.org/thanks'
    end
  end
end
