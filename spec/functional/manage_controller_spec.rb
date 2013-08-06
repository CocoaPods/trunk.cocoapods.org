require File.expand_path('../../spec_helper', __FILE__)
require 'app/controllers/manage_controller'

module Pod::PushApp
  describe ManageController do
    extend Rack::Test::Methods

    def app
      ManageController
    end

    before do
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(:pod => @pod, :name => '1.2.0', :url => 'http://host/pods/AFNetworking/versions/1.2.0')
      @job = @version.add_submission_job(:specification_data => fixture_read('AFNetworking.podspec'))
    end

    it "disallows access without authentication" do
      get '/jobs'
      last_response.status.should == 401
    end

    it "disallows access with incorrect authentication" do
      authorize 'admin', 'incorrect'
      last_response.status.should == 401
    end

    before do
      authorize 'admin', 'secret'
    end

    it "shows a list of current submission jobs" do
      @job.update(:succeeded => nil)
      get '/jobs'
      last_response.should.be.ok
      last_response.body.should.include @pod.name
    end

    it "shows a list of failed submission jobs" do
      @job.update(:succeeded => false)
      get '/jobs?scope=failed'
      last_response.should.be.ok
      last_response.body.should.include @pod.name
    end

    it "shows a list of succeeded submission jobs" do
      @job.update(:succeeded => true)
      get '/jobs?scope=succeeded'
      last_response.should.be.ok
      last_response.body.should.include @pod.name
    end

    it "shows a list of all submission jobs" do
      [nil, false, true].each do |scope|
        @job.update(:succeeded => scope)
        get '/jobs?scope=all'
        last_response.should.be.ok
        last_response.body.should.include @pod.name
      end
    end
  end
end
