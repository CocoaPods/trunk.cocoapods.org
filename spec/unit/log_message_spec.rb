require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/log_message'

module Pod::TrunkApp
  describe LogMessage do
    describe "concerning validations" do
      before do
        @message = LogMessage.new(:message => 'yay', :submission_job_id => 42)
      end

      it "needs a message" do
        @message.should.not.validate_with(:message, nil)
        @message.should.not.validate_with(:message, ' ')
        @message.should.validate_with(:message, 'yay')
      end

      it "needs a submission job" do
        @message.should.not.validate_with(:submission_job_id, nil)
        @message.should.validate_with(:submission_job_id, 42)
      end

      describe "at the DB level" do
        it "raises if an empty `message' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @message.message = nil
            @message.save(:validate => false)
          end
        end

        it "raises if an empty `submission_job_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @message.submission_job_id = nil
            @message.save(:validate => false)
          end
        end
      end
    end
  end
end

