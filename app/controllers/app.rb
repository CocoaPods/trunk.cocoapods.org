require 'app/controllers/api_controller'
require 'app/controllers/manage_controller'

module Pod
  module PushApp
    App = Rack::Builder.new do
      run APIController
    end
  end
end
