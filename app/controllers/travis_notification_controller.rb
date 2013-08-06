require 'sinatra/base'
require 'cocoapods-core'

require 'db/config'
require 'app/models/submission_job'
require 'app/models/travis'

module Pod
  module PushApp
    class TravisNotificationController < Sinatra::Base
      configure do
        set :root, ROOT
      end

      configure :development, :production do
        enable :logging
      end

      before do
        error 415 unless request.media_type == 'application/x-www-form-urlencoded'
        error 401 unless Travis.authorized_webhook_notification?(env['HTTP_AUTHORIZATION'])
      end

      post '/builds' do
        travis = Travis.new(JSON.parse(request.POST['payload']))
        if travis.pull_request? && job = SubmissionJob.find(:pull_request_number => travis.pull_request_number)
          job.update(:travis_build_success => travis.build_success?)
          halt 204
        end
        halt 200
      end
    end
  end
end
