require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod_version'

module Pod::TrunkApp
  describe PodVersion do
    describe 'concerning validations' do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.new(:pod => @pod, :name => '1.2.0')
      end

      it 'needs a pod' do
        @version.should.not.validate_with(:pod_id, nil)
        @version.should.validate_with(:pod_id, @pod.id)
      end

      it 'needs a valid name' do
        @version.should.not.validate_with(:name, nil)
        @version.should.not.validate_with(:name, '')
        @version.should.not.validate_with(:name, ' ')
        @version.should.validate_with(:name, '1.2.0')
      end

      it 'needs a unique name' do
        @version.save
        other_version = PodVersion.new(:pod => @pod, :name => '1.2.0')
        other_version.should.not.validate_with(:name, '1.2.0')
        other_version.should.validate_with(:name, '1.2.1')
      end

      describe 'at the DB level' do
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

        it 'raises if a duplicate pod_id+name gets inserted' do
          should.raise Sequel::UniqueConstraintViolation do
            PodVersion.new(:pod => @pod, :name => '1.2.0').save(:validate => false)
          end
        end

        it 'does not raise if the name already exists, but for a different pod' do
          other_pod = Pod.create(:name => 'ASIHTTPRequest')
          should.not.raise do
            PodVersion.create(:pod => other_pod, :name => '1.2.0')
          end
        end
      end
    end

    describe 'concerning submission progress state' do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
        @committer = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
        @valid_commit_attrs = {
          :committer => @committer,
          :sha => '3ca23060197547eef92983f15590b5a87270615f',
          :specification_data => 'DATA'
        }
      end

      it 'initializes with an unpublished state' do
        @version.should.not.be.published
      end

      it 'returns the destination path in the repo' do
        @version.destination_path.should == 'Specs/AFNetworking/1.2.0/AFNetworking.podspec.json'
      end

      it 'returns a URL from where the spec data can be retrieved' do
        @version.add_commit(@valid_commit_attrs)
        expected = 'https://raw.githubusercontent.com/CocoaPods/Specs/' \
          "3ca23060197547eef92983f15590b5a87270615f/#{@version.destination_path}"
        @version.data_url.should == expected
      end

      it 'returns the resource path for this version' do
        @version.resource_path.should == '/AFNetworking/versions/1.2.0'
      end

      it 'is published if it has commits' do
        @version.add_commit(@valid_commit_attrs)
        @version.should.be.published
      end
    end

    describe 'concerning URL encoding' do
      before do
        @pod = Pod.create(:name => 'NSAttributedString-@+CCLFormat')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
        @committer = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
        @valid_commit_attrs = {
          :committer => @committer,
          :sha => '3ca23060197547eef92983f15590b5a87270615f',
          :specification_data => 'DATA'
        }
      end

      it 'returns a URL from where the spec data can be retrieved' do
        @version.add_commit(@valid_commit_attrs)
        expected = 'https://raw.githubusercontent.com/CocoaPods/Specs/' \
          '3ca23060197547eef92983f15590b5a87270615f/Specs/' \
          'NSAttributedString-@+CCLFormat/1.2.0/NSAttributedString-@+CCLFormat.podspec.json'
        @version.data_url.should == expected
      end
    end

    describe 'concerning its methods' do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
        @committer = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
        @valid_commit_attrs = {
          :committer => @committer,
          :sha => '3ca23060197547eef92983f15590b5a87270615f',
          :specification_data => 'DATA'
        }
      end

      it 'returns whether it was just created' do
        @version.was_created?.should == true
        PodVersion.find(:name => @version.name).was_created?.should == false
      end

      it 'has a description' do
        @version.description.should == 'AFNetworking 1.2.0'
      end
    end

    describe 'concerning who did what on the version' do
      before do
        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
        @committer = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
        @valid_commit_attrs = {
          :committer => @committer,
          :sha => '3ca23060197547eef92983f15590b5a87270615f',
          :specification_data => 'DATA'
        }
      end

      it 'has been last published by the last pushed commit' do
        @version.add_commit(@valid_commit_attrs)
        last_commit = @version.add_commit(@valid_commit_attrs.merge(:sha => '7f694a5c1e43543a803b5d20d8892512aae375f3'))
        @version.last_published_by.should == last_commit
      end

      it 'has the same sha as the last pushed commit' do
        @version.add_commit(@valid_commit_attrs)
        last_commit = @version.add_commit(@valid_commit_attrs.merge(:sha => '7f694a5c1e43543a803b5d20d8892512aae375f3'))
        @version.commit_sha.should == last_commit.sha
      end
    end

    describe '#push!' do
      extend SpecHelpers::CommitResponse

      before do
        @response = response(201, { :commit => { :sha => '3ca23060197547eef92983f15590b5a87270615f' } }.to_json)
        PushJob.any_instance.stubs(:push!).returns(@response)

        @pod = Pod.create(:name => 'AFNetworking')
        @version = PodVersion.create(:pod => @pod, :name => '1.2.0')
        @committer = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
      end

      it 'adds the committer as the owner of the pod if the pod has no owners yet' do
        @pod.reload.owners.should == []
        @version.push! @committer, 'DATA', 'Add'
        @pod.reload.owners.should == [@committer]
      end

      it 'adds a commit' do
        @version.commits.should == []
        @version.push! @committer, 'DATA', 'Add'
        @version.commits.size.should == 1
        @version.commits.last.sha.should == '3ca23060197547eef92983f15590b5a87270615f'
      end

      it 'returns truthy' do
        @version.push!(@committer, 'DATA', 'Add').should == @response
      end

      before do
        @response = response(500)
        PushJob.any_instance.stubs(:push!).returns(@response)
      end

      it 'does not add the committer as the owner of the pod if the pod pushing fails' do
        @pod.reload.owners.should == []
        @version.push! @committer, 'DATA', 'Add'
        @pod.reload.owners.should == []
      end

      it 'does not add a commit' do
        @version.commits.should == []
        @version.push! @committer, 'DATA', 'Add'
        @version.commits.should == []
      end

      it 'returns falsy' do
        @version.push!(@committer, 'DATA', 'Add').should.not.be.success
      end

    end
  end
end
