require File.expand_path('../../spec_helper', __FILE__)
require 'app/models/pod'

module Pod::TrunkApp
  describe Pod do
    describe 'concerning validations' do
      before do
        @pod = Pod.new(:name => 'AFNetworking')
      end

      it 'needs a valid name' do
        @pod.should.not.validate_with(:name, nil)
        @pod.should.not.validate_with(:name, '')
        @pod.should.not.validate_with(:name, ' ')
        @pod.should.validate_with(:name, 'AFNetworking')
      end

      it 'needs a unique name' do
        Pod.create(:name => 'AFNetworking')
        @pod.should.not.validate_with(:name, 'AFNetworking')
      end

      describe 'at the DB level' do
        it 'raises if an empty name gets inserted' do
          should.raise Sequel::NotNullConstraintViolation do
            Pod.new(:name => nil).save(:validate => false)
          end
        end

        it 'raises if a duplicate name gets inserted' do
          Pod.create(:name => 'AFNetworking')
          should.raise Sequel::UniqueConstraintViolation do
            Pod.new(:name => 'AFNetworking').save(:validate => false)
          end
        end
      end
    end

    describe 'in general' do
      it 'returns whether it was just created' do
        pod = Pod.create(:name => 'AFNetworking')
        pod.was_created?.should == true
        Pod.find(:name => pod.name).was_created?.should == false
      end

      before do
        @owner = Owner.create(:email => 'jenny@example.com', :name => 'Jenny Penny')
      end

      it 'adds an owner' do
        owner2 = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
        pod = @owner.add_pod(:name => 'AFNetworking')
        pod.add_owner(owner2)
        pod.owners.should == [@owner, owner2]
      end

      it 'does not find an unexisting pod' do
        Pod.find_by_name_and_owner('CocoaLumberjack', @owner).should.be.nil
      end

      it "returns an existing pod if it's owned by the specified owner" do
        pod = @owner.add_pod(:name => 'AFNetworking')
        Pod.find_by_name_and_owner('AFNetworking', @owner).should == pod
      end

      it "does not return a pod if it's owned by another user" do
        other_owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
        other_owner.add_pod(:name => 'AFNetworking')
        Pod.find_by_name_and_owner('AFNetworking', @owner).should.be.nil
      end

      it "yields the 'no access allowed' block if it's owned by another user" do
        other_owner = Owner.create(:email => 'appie@example.com', :name => 'Appie Duran')
        other_owner.add_pod(:name => 'AFNetworking')
        yielded = false
        Pod.find_by_name_and_owner('AFNetworking', @owner) { yielded = true }
        yielded.should == true
      end
    end

    describe 'concerning webhooks' do
      before do
        Webhook.pod_created = %w(pod_created_url1 pod_created_url2)
      end
      after do
        Webhook.pod_created = []
      end
      it 'sends off a Webhook message' do
        sha = '7f694a5c1e43543a803b5d20d8892512aae375f3'
        version = '1.0.0'

        Webhook.expects(:call).once.with do |type, action, json|
          type.should == 'pod'
          action.should == 'create'
          json.should.match(/"type":"pod"/)
          json.should.match(/"action":"create"/)
          json.should.match(/"timestamp":/)
          json.should.match(/"data_url":"TODO"/)
        end

        Pod.send :alias_method, :after_save, :after_commit
        @pod = Pod.create(:name => 'Webhook')
        Pod.send :remove_method, :after_save
      end
    end
  end
end
