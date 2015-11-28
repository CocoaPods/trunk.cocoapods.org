require File.expand_path('../../../spec_helper', __FILE__)
require 'app/controllers/api/owners_controller'

module Pod::TrunkApp
  describe OwnersController, 'concerning the details of a single owner' do
    extend SpecHelpers::Response

    before do
      header 'Content-Type', 'application/json'
    end

    seed_unclaimed

    it 'shows an owners public attributes' do
      owner = Owner.unclaimed
      pod1 = Pod.new(:name => 'Test1')
      pod2 = Pod.new(:name => 'Test2')
      owner.add_pod(pod1)
      owner.add_pod(pod2)

      get "/#{owner.email}"
      last_response.status.should == 200

      attributes = owner.public_attributes
      attributes['pods'] = [pod1.public_attributes, pod2.public_attributes]
      json_response.should == JSON.parse(attributes.to_json)
    end

    it '404s if no such owner is found' do
      get '/not-even-a-valid-email'
      last_response.status.should == 404
    end
  end
end
