require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/dispute'

module Pod::TrunkApp
  describe Dispute do
    before do
      @claimer = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @dispute = Dispute.new(:claimer => @claimer, :message => 'GIMME!')
    end

    describe 'concerning validations' do
      it 'needs a claimer' do
        @dispute.should.not.validate_with(:claimer_id, nil)
        @dispute.should.validate_with(:claimer_id, @claimer.id)
      end

      it 'needs a message' do
        @dispute.should.not.validate_with(:message, nil)
        @dispute.should.not.validate_with(:message, '')
        @dispute.should.not.validate_with(:message, ' ')
        @dispute.should.validate_with(:message, 'GIMME!')
      end
    end
  end
end
