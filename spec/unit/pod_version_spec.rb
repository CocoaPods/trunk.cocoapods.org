require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod_version'

module Pod::TrunkApp
  describe PodVersion do
    describe "concerning validations" do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        PodVersion.create(:pod => @pod, :name => '1.2.0')
      end

      it "raises if for whatever reason a duplicate pod_id+name gets inserted into the DB" do
        should.raise Sequel::UniqueConstraintViolation do
          PodVersion.create(:pod => @pod, :name => '1.2.0')
        end
      end

      it "does not raise if the name already exists in the DB, but for a different pod" do
        other_pod = Pod.create(:name => 'ASIHTTPRequest')
        should.not.raise do
          PodVersion.create(:pod => other_pod, :name => '1.2.0')
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
