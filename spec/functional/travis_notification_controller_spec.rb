require File.expand_path('../../spec_helper', __FILE__)
require 'app/controllers/travis_notification_controller'

module Pod::TrunkApp
  describe TravisNotificationController do
    extend Rack::Test::Methods

    def app
      TravisNotificationController
    end

    before do
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(
        :pod => @pod,
        :name => '1.2.0',
        :url => 'http://host/pods/AFNetworking/versions/1.2.0'
      )
      @job = @version.add_submission_job(
        :specification_data => fixture_read('AFNetworking.podspec'),
        :needs_to_perform_work => false,
        :pull_request_number => NEW_PR_NUMBER,
      )
    end

    before do
      header 'Content-Type', 'application/x-www-form-urlencoded'
    end

    it "does not allow updates to submission job's if the client isn't authorized" do
      post '/builds', { 'payload' => fixture_read('TravisCI/pull-request_success_payload.json') }, { 'HTTP_AUTHORIZATION' => 'incorrect token' }
      last_response.status.should == 401
      @job.reload.travis_build_success?.should == nil
      @job.should.not.needs_to_perform_work
    end

    before do
      header 'Authorization', Travis.webhook_authorization_token
    end

    it "does not break with a normal commit notification" do
      post '/builds', { 'payload' => fixture_read('TravisCI/commit_payload.json') }
      last_response.status.should == 200
      @job.reload.travis_build_success?.should == nil
      @job.should.not.needs_to_perform_work
    end

    it "does not break with a notification for an unknown pull-request" do
      post '/builds', { 'payload' => fixture_read('TravisCI/pull-request_unknown_payload.json') }
      last_response.status.should == 200
      @job.reload.travis_build_success?.should == nil
      @job.should.not.needs_to_perform_work
    end

    it "only updates the build url with a start notification" do
      post '/builds', { 'payload' => fixture_read('TravisCI/pull-request_start_payload.json') }
      last_response.status.should == 204
      @job.reload.travis_build_success?.should == nil
      @job.travis_build_url.should == 'https://travis-ci.org/CocoaPods/push.cocoapods.org/builds/7540815'
      @job.should.not.needs_to_perform_work
    end

    it "updates the submission job's build status as passing the lint process" do
      post '/builds', { 'payload' => fixture_read('TravisCI/pull-request_success_payload.json') }
      last_response.status.should == 204
      @job.reload.travis_build_success?.should == true
      @job.travis_build_url.should == 'https://travis-ci.org/CocoaPods/push.cocoapods.org/builds/7540815'
      @job.should.needs_to_perform_work
    end

    it "updates the submission job's build status as failing the lint process" do
      post '/builds', { 'payload' => fixture_read('TravisCI/pull-request_failure_payload.json') }
      last_response.status.should == 204
      @job.reload.travis_build_success?.should == false
      @job.travis_build_url.should == 'https://travis-ci.org/CocoaPods/push.cocoapods.org/builds/7541777'
      @job.should.be.failed
    end
  end
end
