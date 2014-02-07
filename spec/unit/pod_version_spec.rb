require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod_version'

module Pod::TrunkApp
  describe PodVersion do
    describe "concerning validations" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.new(:pod => @pod, :name => '1.2.0')
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
        other_version.should.not.validate_with(:name, '1.2.0', [:pod_id, :name])
        other_version.should.validate_with(:name, '1.2.1', [:pod_id, :name])
      end

      it "needs a published status" do
        @version.should.not.validate_with(:published, nil)
        @version.should.not.validate_with(:published, '')
        @version.should.validate_with(:published, false)
        @version.should.validate_with(:published, true)
      end

      it "needs a valid commit sha" do
        @version.should.not.validate_with(:commit_sha, '')
        @version.should.not.validate_with(:commit_sha, '3ca23060')
        @version.should.not.validate_with(:commit_sha, 'g' * 40) # hex only
        @version.should.validate_with(:commit_sha, '3ca23060197547eef92983f15590b5a87270615f')
      end

      describe "at the DB level" do
        it "raises if an empty `name' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @version.name = nil
            @version.save(:validate => false)
          end
        end

        it "raises if an empty `published' gets inserted" do
          should.raise Sequel::NotNullConstraintViolation do
            @version.published = nil
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
        @version.commit_sha = 'commit-sha'
        @version.data_url.should == "https://raw.github.com/CocoaPods/Specs/commit-sha/#{@version.destination_path}"
      end

      it "returns the resource path for this version" do
        @version.resource_path.should == '/pods/AFNetworking/versions/1.2.0'
      end
    end
  end
end
