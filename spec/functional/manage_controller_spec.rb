require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe ManageController do
    before do
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      @commit = @version.add_commit(
        :committer => @owner,
        :sha => '3ca23060197547eef92983f15590b5a87270615f',
        :specification_data => 'DATA'
      )
      @messages = [
        @version.add_log_message(:reference => 'ref1', :level => :info,  :message => 'log message 1'),
        @version.add_log_message(:reference => 'ref2', :level => :error, :message => 'log message 2'),
      ]
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

    it "shows a list of commits" do
      get '/commits'
      last_response.should.be.ok
      last_response.body.should.include @version.name
    end

    it "shows an overview of an individual commit" do
      get "/commits/#{@commit.id}"
      last_response.should.be.ok
      last_response.body.should.include @version.name
    end

    it "shows a list of all pod versions" do
      get '/versions'
      last_response.should.be.ok
      last_response.body.should.include @version.name
    end
    
    it "shows a list of all messages" do
      get '/log_messages'
      last_response.should.be.ok
      last_response.body.should.include 'info'
    end
    
    it "shows a list of all filtered messages" do
      get '/log_messages?reference=ref1'
      last_response.should.be.ok
      last_response.body.should.include 'ref1'
      last_response.body.should.not.include 'ref2'
    end
    
    it "shows a list of all filtered messages" do
      get '/log_messages?reference=nothere'
      last_response.should.be.ok
      last_response.body.should.not.include 'ref1'
      last_response.body.should.not.include 'ref2'
    end
  end
end
