require File.expand_path('../../spec_helper', __FILE__)
require 'nokogiri'

module Pod::TrunkApp
  describe ClaimsController, "when claiming pods" do
    it "renders a new claim form" do
      get '/new'
      last_response.status.should == 200
      last_response.body.should.include '<form action="/claims"'
      Nokogiri::HTML(last_response.body).css('form').first['action'].should == '/claims'
    end

    it "does not create an owner if no pods are specified" do
      lambda {
        post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => []
      }.should.not.change { Owner.count }
      last_response.status.should == 200
      form = Nokogiri::HTML(last_response.body).css('form').first
      form['action'].should == '/claims'
      form.css('input[name="person[email]"]').first['value'].should == 'appie@example.com'
      form.css('input[name="person[name]"]').first['value'].should == 'Appie Duran'
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

    it "rollsback in case of an error" do
      Pod.any_instance.stubs(:remove_owner).raises
      lambda {
        should.raise do
          post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
        end
      }.should.not.change { Owner.count }
      @pod.reload.owners.should == [Owner.unclaimed]
    end

    it "lists unknown pods" do
    end

    it "lists already claimed pods" do
    end

    it "redirects to the thanks page after successfully assigning pods" do
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      last_response.location.should == 'https://example.org/thanks'
    end
  end
end