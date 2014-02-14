require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod_version'

module Pod::TrunkApp
  describe PodVersion do
    describe "concerning validations" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.new(:pod => @pod, :name => '1.2.0')
      end

      it "needs a pod" do
        @version.should.not.validate_with(:pod_id, nil)
        @version.should.validate_with(:pod_id, @pod.id)
      end

      it "needs a valid name" do
        @version.should.not.validate_with(:name, nil)
        @version.should.not.validate_with(:name, '')
        @version.should.not.validate_with(:name, ' ')
        @version.should.validate_with(:name, '1.2.0')
      end

      it "needs a unique name" do
        @version.save
        other_version = PodVersion.new(:pod => @pod, :name => '1.2.0')
        other_version.should.not.validate_with(:name, '1.2.0')
        other_version.should.validate_with(:name, '1.2.1')
      end

      describe "at the DB level" do
        it "raises if an empty `pod_id' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @version.pod_id = nil
            @version.save(:validate => false)
          end
        end

        it "raises if an empty `name' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @version.name = nil
            @version.save(:validate => false)
          end
        end

        before do
          @version.save
        end

        it "raises if a duplicate pod_id+name gets inserted" do
          should.raise Sequel::UniqueConstraintViolation do
            PodVersion.new(:pod => @pod, :name => '1.2.0').save(:validate => false)
          end
        end

        it "does not raise if the name already exists, but for a different pod" do
          other_pod = Pod.create(:name => 'ASIHTTPRequest')
          should.not.raise do
            PodVersion.create(:pod => other_pod, :name => '1.2.0')
          end
        end
      end
    end

    describe "concerning submission progress state" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "initializes with an unpublished state" do
        @version.should.not.be.published
      end

      it "returns the destination path in the repo" do
        @version.destination_path.should == 'Specs/AFNetworking/1.2.0/AFNetworking.podspec.json'
      end

      it "returns a URL from where the spec data can be retrieved" do
        @version.add_commit(:pushed => true, :sha => '3ca23060197547eef92983f15590b5a87270615f', :specification_data => 'data')
        @version.data_url.should == "https://raw.github.com/CocoaPods/Specs/3ca23060197547eef92983f15590b5a87270615f/#{@version.destination_path}"
      end

      it "returns the resource path for this version" do
        @version.resource_path.should == '/pods/AFNetworking/versions/1.2.0'
      end
      
      it "is published if any of its commits are pushed" do
        @version.add_commit(:pushed => false, :specification_data => 'DATA')
        @version.add_commit(:pushed => true, :specification_data => 'DATA')
        @version.should.be.published
      end
      
      it "is not published if its commits are in progress" do
        @version.add_commit(:pushed => nil, :specification_data => 'DATA')
        @version.should.not.be.published
      end
      
      it "is not published if none of its commits has succeeded" do
        @version.add_commit(:pushed => false, :specification_data => 'DATA')
        @version.add_commit(:pushed => nil, :specification_data => 'DATA')
        @version.should.not.be.published
      end
    end
    
    describe "concerning who did what on the version" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "has been published by all successfully pushed commits" do
        successful_commit = @version.add_commit(:pushed => true, :specification_data => 'DATA')
        @version.add_commit(:pushed => false, :specification_data => 'DATA')
        @version.add_commit(:pushed => nil, :specification_data => 'DATA')
        last_successful_commit = @version.add_commit(:pushed => true, :specification_data => 'DATA')
        @version.published_by.should == [successful_commit, last_successful_commit]
      end

      it "has been last published by the last pushed commit" do
        @version.add_commit(:pushed => false, :specification_data => 'DATA')
        last_commit = @version.add_commit(:pushed => true, :specification_data => 'DATA')
        @version.last_published_by.should == last_commit
      end
      
      it "has the same sha as the last pushed commit" do
        @version.add_commit(:pushed => true, :sha => '4ca23060197547eef92983f15590b5a87270615f', :specification_data => 'DATA')
        last_commit = @version.add_commit(
          :pushed => true,
          :sha => '3ca23060197547eef92983f15590b5a87270615f',
          :specification_data => 'DATA')
        @version.commit_sha.should == last_commit.sha
      end
    end
  end
end
