require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/submission_job'

module Pod::TrunkApp
  class SubmissionJob
    public :perform_work
  end

  describe "SubmissionJob" do
    before do
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @pod = Pod.create(:name => 'AFNetworking')
      @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      @job = @version.add_submission_job(:specification_data => fixture_read('AFNetworking.podspec'), :owner => @owner)
    end

    it "returns the duration in seconds relative to now" do
      now = 41.seconds.from_now
      Time.stubs(:now).returns(now)
      @job.duration.should == 42
    end

    it "returns the duration in seconds relative till the latest update once finished" do
      @job.update(:succeeded => false)
      now = 41.seconds.from_now
      Time.stubs(:now).returns(now)
      @job.duration.should == 1
    end

    before do
      @github = @job.class.send(:github)
    end

    it "configures the GitHub client" do
      @github.basic_auth.should == { :username => 'secret', :password => 'x-oauth-basic' }
    end

    it "initializes with a new state" do
      @job.should.be.in_progress
    end

    it "creates log messages before anything else and gets persisted regardless of further errors" do
      result = @job.perform_work 'A failing task' do
        @job.update(:commit_sha => 'sha')
        raise "oh noes!"
      end
      result.should == false
      @job.log_messages.last(2).map(&:message).should == ["A failing task", "Failed with error: oh noes!"]
      @job.reload.commit_sha.should == nil

      result = @job.perform_work 'A succeeding task' do
        @job.update(:commit_sha => 'sha')
      end
      result.should == true
      @job.log_messages.last.message.should == "A succeeding task"
      @job.reload.commit_sha.should == 'sha'
    end

    it "reports it failed" do
      @github.stubs(:create_new_commit).raises
      @job.submit_specification_data!.should == false
      @job.reload.should.be.failed
      @job.should.not.be.completed
    end

    before do
      @github.stubs(:create_new_commit).with(@version.destination_path,
                                             @job.specification_data,
                                             MESSAGE,
                                             'Appie',
                                             'appie@example.com').returns(fixture_new_commit_sha)
    end

    it "creates a new commit" do
      @job.submit_specification_data!.should == true
      @job.reload.commit_sha.should == fixture_new_commit_sha
      @job.reload.should.be.completed
      @job.should.not.be.failed
      @job.log_messages.first.message.should == 'Submitting specification data to GitHub'
    end

    it "publishes the pod version once the commit has been created" do
      @job.submit_specification_data!
      @version.should.be.published
      @version.published_by_submission_job.should == @job
      @version.commit_sha.should == fixture_new_commit_sha
      @job.log_messages.last.message.should == "Published."
    end
  end
end
