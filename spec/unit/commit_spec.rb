require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/commit'

module Pod::TrunkApp
  describe Commit do
    before do
      @pod = Pod.create(:name => 'AFNetworking')
      @version = @pod.add_version(:name => '1.2.0')
      @owner = Owner.create(:email => 'appie@example.com', :name => 'Appie')
      @commit = Commit.new(:committer => @owner, :pod_version => @version, :specification_data => fixture_read('AFNetworking.podspec'))
    end

    describe "concerning validations" do
      it "needs a pod version" do
        @commit.should.not.validate_with(:pod_version_id, nil)
        @commit.should.validate_with(:pod_version_id, @version.id)
      end

      it "needs specification data" do
        @commit.should.not.validate_with(:specification_data, nil)
        @commit.should.not.validate_with(:specification_data, '')
        @commit.should.not.validate_with(:specification_data, ' ')
        @commit.should.validate_with(:specification_data, fixture_read('AFNetworking.podspec'))
      end

      it "needs a valid commit sha" do
        @commit.should.not.validate_with(:sha, '')
        @commit.should.not.validate_with(:sha, '3ca23060')
        @commit.should.not.validate_with(:sha, 'g' * 40) # hex only
        @commit.should.validate_with(:sha, nil)
        @commit.should.validate_with(:sha, '3ca23060197547eef92983f15590b5a87270615f')
      end

      it "needs a committer" do
        @commit.should.not.validate_with(:committer_id, nil)
        @commit.should.validate_with(:committer_id, @owner.id)
      end

      describe "at the DB level" do
        it "raises if an empty `committer_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @commit.committer_id = nil
            @commit.save(:validate => false)
          end
        end

        it "raises if an empty `pod_version_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @commit.pod_version_id = nil
            @commit.save(:validate => false)
          end
        end

        it "raises if an empty `specification_data' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @commit.specification_data = nil
            @commit.save(:validate => false)
          end
        end
      end
    end

    describe "in general" do
      before do
        @commit.save
      end
      
      it "initializes with a new state" do
        @commit.should.be.in_progress
      end
    end
    
    describe "class methods" do
      before do
        @in_progress = Commit.create(:committer => @owner, :pod_version => @version, :pushed => nil, :specification_data => 'DATA')
        @succeeded   = Commit.create(:committer => @owner, :pod_version => @version, :pushed => true, :specification_data => 'DATA')
        @failed      = Commit.create(:committer => @owner, :pod_version => @version, :pushed => false, :specification_data => 'DATA')
      end
      
      it "returns commits in progress" do
        Commit.in_progress.should == [@in_progress]
      end
      
      it "returns successful commits" do
        Commit.succeeded.should == [@succeeded]
      end
      
      it "returns failed commits" do
        Commit.failed.should == [@failed]
      end
    end
  end
end
