require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe ManageController do
    before do
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      @commit = Commit.create(:pod_version => @version, :specification_data => fixture_read('AFNetworking.podspec'))
      @job = PushJob.create(:commit => @commit, :owner => @owner)
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
      @commit.update(:pushed => nil)
      get '/commits'
      last_response.should.be.ok
      last_response.body.should.include @commit.pod_version.name
    end

    it "shows a list of failed submission jobs" do
      @commit.update(:pushed => false)
      get '/commits', :scope => 'failed'
      last_response.should.be.ok
      last_response.body.should.include @commit.pod_version.name
    end

    it "shows a list of succeeded submission jobs" do
      @commit.update(:pushed => true)
      get '/commits', :scope => 'succeeded'
      last_response.should.be.ok
      last_response.body.should.include @commit.pod_version.name
    end

    it "shows a list of all submission jobs" do
      [nil, false, true].each do |scope|
        @commit.update(:pushed => scope)
        get '/commits', :scope => 'all'
        last_response.should.be.ok
        last_response.body.should.include @commit.pod_version.name
      end
    end

    it "shows an overview of an individual commit" do
      @commit.update(:pushed => true)
      get "/commits/#{@commit.id}"
      last_response.should.be.ok
      last_response.body.should.include @commit.pod_version.name
    end

    it "shows a list of all pod versions" do
      get '/versions'
      last_response.should.be.ok
      last_response.body.should.include @version.name
    end
  end
end
