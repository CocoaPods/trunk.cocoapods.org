require 'app/controllers/api_controller'
require 'app/controllers/manage_controller'

module Pod
  module PushApp
    App = Rack::Builder.new do
      run APIController
      map '/manage' do
        run ManageController
      end
    end
  end
end
