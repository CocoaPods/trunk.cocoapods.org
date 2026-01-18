require File.expand_path('../spec_helper', __dir__)

module Pod::TrunkApp
  describe DisputesController, 'concerning disputes' do
    before do
      @owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny')
      @pod = @owner.add_pod(:name => 'AFNetworking')
    end

    it 'lists already claimed pods' do
      get '/new', :claimer_email => 'appie@example.com', :pods => ['AFNetworking']
      last_response.status.should == 200
      container = response_doc.css('article').first
      container.css('li').first.text.should == 'AFNetworking <jenny@example.com>'
      form = container.css('form').first
      form.css('input[name="claimer_email"]').first['value'].should == 'appie@example.com'
      form.css('textarea').first.text.should.include 'AFNetworking'
    end

    it 'creates a new dispute' do
      lambda do
        post '/', :claimer_email => @owner.email, :message => 'GIMME!'
      end.should.change { Dispute.count } # rubocop:disable Style/MultilineBlockChain
      last_response.location.should == 'https://example.org/thanks'
      dispute = Dispute.last
      dispute.claimer.should == @owner
      dispute.message.should == 'GIMME!'
      dispute.should.not.be.settled
    end

    it 'shows a thanks page' do
      get '/thanks'
      last_response.status.should == 200
    end
  end
end
