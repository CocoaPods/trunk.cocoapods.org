require 'app/controllers/api_controller'
require 'app/controllers/manage_controller'
require 'app/controllers/travis_notification_controller'

module Pod
  module TrunkApp
    App = Rack::URLMap.new(
      '/' => APIController,
      '/manage' => ManageController,
      '/travis' => TravisNotificationController
    )
  end
end
