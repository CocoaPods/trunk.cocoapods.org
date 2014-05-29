require File.expand_path('../../../spec_helper', __FILE__)
require 'app/controllers/api/owners_controller'

module Pod::TrunkApp
  describe OwnersController, 'concerning the details of a single owner' do
    extend SpecHelpers::Response

    before do
      header 'Content-Type', 'application/json'
    end

    it 'shows an owners public attributes' do
      owner = Owner.unclaimed
      get "/#{owner.email}"
      last_response.status.should == 200
      attributes = owner.public_attributes
      json_response.should == JSON.parse(attributes.to_json)
    end
  end
end