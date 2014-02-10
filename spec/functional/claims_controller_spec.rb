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
      @unclaimed_owner = Owner.create(:email => 'unclaimed-pods@example.com', :name => 'Unclaimed Pods')
      @pod = @unclaimed_owner.add_pod(:name => 'AFNetworking')
    end

    it "creates an owner and assigns it to the claimed pods" do
      lambda {
        post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      }.should.change { Owner.count }
      owner = Owner.find_by_email('appie@example.com')
      owner.name.should == 'Appie Duran'
      owner.pods.to_a.should == [@pod]
    end

    it "finds an existing owner and assigns it to the claimed pods" do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      lambda {
        post '/', :owner => { :email => 'appie@example.com' }, :pods => ['AFNetworking']
      }.should.not.change { Owner.count }
      owner.reload.pods.to_a.should == [@pod]
    end

    it "finds an existing owner and updates its name if specified" do
      owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      post '/', :owner => { :email => 'appie@example.com', :name => ' ' }, :pods => ['AFNetworking']
      owner.reload.name.should == 'Appie Duran'
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appiepocalypse' }, :pods => ['AFNetworking']
      owner.reload.name.should == 'Appiepocalypse'
    end

    it "redirects to the thanks page" do
      post '/', :owner => { :email => 'appie@example.com', :name => 'Appie Duran' }, :pods => ['AFNetworking']
      last_response.location.should == 'https://example.org/thanks'
    end
  end
end
