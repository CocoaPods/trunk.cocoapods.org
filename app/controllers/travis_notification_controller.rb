require 'app/controllers/app_controller'
require 'app/models/submission_job'
require 'app/models/travis'

module Pod
  module TrunkApp
    class TravisNotificationController < AppController
      before do
        error 415 unless request.media_type == 'application/x-www-form-urlencoded'
        error 401 unless Travis.authorized_webhook_notification?(env['HTTP_AUTHORIZATION'])
      end

      post '/builds' do
        travis = Travis.new(JSON.parse(request.POST['payload']))
        if travis.pull_request? && job = SubmissionJob.find(:pull_request_number => travis.pull_request_number)
          job.update_travis_build_status(travis)
          halt 204
        end
        halt 200
      end
    end
  end
end
