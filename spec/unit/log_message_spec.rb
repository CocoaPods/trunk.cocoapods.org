require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/log_message'

module Pod::TrunkApp
  describe LogMessage do
    describe 'concerning validations' do
      before do
        @message = LogMessage.new(:level => :info, :message => 'yay', :pod_version_id => 42)
      end

      it 'needs a valid level' do
        @message.should.not.validate_with(:level, nil)
        @message.should.not.validate_with(:level, ' ')
        @message.should.not.validate_with(:level, :warn)
        @message.should.validate_with(:level, :info)
        @message.should.validate_with(:level, :warning)
        @message.should.validate_with(:level, :error)
      end

      it 'needs a message' do
        @message.should.not.validate_with(:message, nil)
        @message.should.not.validate_with(:message, ' ')
        @message.should.validate_with(:message, 'yay')
      end

      it 'does not need an owner' do
        @message.should.validate_with(:owner, nil)
        @message.should.validate_with(:owner, Owner.unclaimed)
      end

      describe 'at the DB level' do
        it "raises if an empty `level' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @message.level = nil
            @message.save(:validate => false)
          end
        end

        it "raises if an empty `message' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @message.message = nil
            @message.save(:validate => false)
          end
        end

        it "does not raise if an empty `submission_job_id' gets inserted" do
          should.not.raise Sequel::NotNullConstraintViolation do
            @message.pod_version_id = nil
            @message.save(:validate => false)
          end
        end
      end
    end
  end
end
