require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/push_job'

module Pod::TrunkApp
  class PushJob
    public :perform_work
  end

  describe PushJob do
    before do
      @pod = Pod.create(:name => 'AFNetworking')
      @version = @pod.add_version(:name => '1.2.0')
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @job = PushJob.new(:owner => @owner)
    end

    describe "concerning validations" do
      it "needs an owner" do
        @job.should.not.validate_with(:owner_id, nil)
        @job.should.validate_with(:owner_id, @owner.id)
      end

      describe "at the DB level" do
        it "raises if an empty `owner_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @job.owner_id = nil
            @job.save(:validate => false)
          end
        end
      end
    end

    describe "in general" do
      before do
        @commit = Commit.create(:pod_version => @version,
                                :specification_data => fixture_read('GitHub/KFData.podspec.json'))
        @job.commit = @commit
        @job.save
      end

      it "returns the duration in seconds relative to now" do
        now = 41.seconds.from_now
        Time.stubs(:now).returns(now)
        @job.duration.should == 42
      end

      it "returns the duration in seconds relative till the latest update once finished" do
        @commit.update(:pushed => false)
        @job.save
        now = 41.seconds.from_now
        Time.stubs(:now).returns(now)
        @job.duration.should == 1
      end

      before do
        @github = @job.class.github
      end

      it "configures the GitHub client" do
        @github.basic_auth.should == { :username => 'secret', :password => 'x-oauth-basic' }
      end

      it "initializes with a new state" do
        @job.should.be.in_progress
      end

      it "creates log messages before anything else and gets persisted regardless of further errors" do
        should.raise do
          @job.perform_work 'A failing task' do
            @job.commit.update(:sha => '3ca23060197547eef92983f15590b5a87270615f')
            raise "oh noes!"
          end
        end
        @job.reload.log_messages.last(2).map(&:message).should == ["A failing task", "Failed with error: oh noes!"]
        @job.commit_sha.should == nil

        should.not.raise do
          @job.perform_work 'A succeeding task' do
            @job.commit.update(:sha => '3ca23060197547eef92983f15590b5a87270615f')
          end
        end
        @job.reload.log_messages.last.message.should == "A succeeding task"
        @job.commit_sha.should == '3ca23060197547eef92983f15590b5a87270615f'
      end

      before do
        @github.stubs(:create_new_commit).with(@version.destination_path,
                                               @job.specification_data,
                                               MESSAGE,
                                               'Appie',
                                               'appie@example.com').returns(fixture_new_commit_sha)
      end

      it "creates a new commit" do
        @job.push!
        @job.reload.commit_sha.should == fixture_new_commit_sha
        @job.log_messages.first.message.should == 'Submitting specification data to GitHub'
      end

      it "publishes the pod version once the commit has been created" do
        @job.push!
        @version.should.be.published
        @version.last_published_by.pushed_by.should == @job
        @version.commit_sha.should == fixture_new_commit_sha
        @job.log_messages.last.message.should == "Published."
      end

      it "adds the submitter as the owner of the pod if the pod has no owners yet" do
        @job.push!
        @pod.reload.owners.should == [@owner]
      end
    end
  end
end
