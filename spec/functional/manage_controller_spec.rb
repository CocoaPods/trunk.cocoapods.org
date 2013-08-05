require File.expand_path('../../spec_helper', __FILE__)
require 'app/controllers/manage_controller'

module Pod::PushApp
  describe ManageController do
    extend Rack::Test::Methods

    def app
      ManageController
    end

    it "shows a list of current submission jobs" do
      get '/jobs'
      last_response.should.be.ok
      puts last_response.body
    end
  end
end
