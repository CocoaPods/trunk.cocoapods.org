require File.expand_path('../../spec_helper', __FILE__)

module Pod::TrunkApp
  describe ManageController do
    it "disallows access without authentication" do
      get '/'
      last_response.status.should == 401
    end

    it "disallows access with incorrect authentication" do
      authorize 'admin', 'incorrect'
      last_response.status.should == 401
    end

    before do
      authorize 'admin', 'secret'

      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      @commit = @version.add_commit(
        :committer => @owner,
        :sha => '3ca23060197547eef92983f15590b5a87270615f',
        :specification_data => 'DATA'
      )
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

    before do
      @version.add_log_message(:reference => 'ref1', :level => :info,  :message => 'log message 1')
      @version.add_log_message(:reference => 'ref2', :level => :error, :message => 'log message 2')
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

      get '/log_messages?reference=nothere'
      last_response.should.be.ok
      last_response.body.should.not.include 'ref1'
      last_response.body.should.not.include 'ref2'
    end

    before do
      @disputes = [
        Dispute.create(:claimer => @owner, :message => 'unsetled'),
        Dispute.create(:claimer => @owner, :message => 'settled', :settled => true),
      ]
    end

    it "shows a list of all disputes" do
      get '/disputes'
      last_response.status.should == 200
      response_doc.css('table tbody tr').size.should == 2
    end

    it "shows a list of all unsettled disputes" do
      get '/disputes?scope=unsettled'
      last_response.status.should == 200
      response_doc.css('table tbody tr').size.should == 1
    end

    it "shows an overview of a dispute" do
      get "/disputes/#{@disputes.first.id}"
      last_response.status.should == 200
    end
  end
end
