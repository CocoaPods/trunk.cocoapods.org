require File.expand_path('../../spec_helper', __FILE__)

require 'app/models/pod'
require 'app/models/pod_version'
require 'app/models/commit'
require 'webhook'

module Pod::TrunkApp
  describe 'Webhook' do
    before do
      Webhook.pod_created = %w(pod_created_url1 pod_created_url2)
      Webhook.version_created = %w(version_created_url1 version_created_url2)
      Webhook.spec_updated = %w(spec_updated_url1 spec_updated_url2)
    end
    after do
      Webhook.pod_created = []
      Webhook.version_created = []
      Webhook.spec_updated = []
    end

    def self.name
      'Webhook'
    end

    def self.sha
      '7f694a5c1e43543a803b5d20d8892512aae375f3'
    end

    def self.version_name
      '1.0.0'
    end

    def self.expect_events(*methods)
      methods.each do |method|
        Webhook.expects(method).once
      end
    end

    def self.add_commit(version)
      @committer = Owner.create(:email => 'appie-webhook@example.com', :name => 'Appie Duran')
      version.add_commit(:committer => @committer, :sha => sha, :specification_data => 'DATA')
    end

    describe 'with newly created pod' do
      before do
        @pod = Pod.create(:name => name)
      end
      describe 'that was loaded from the DB' do
        before do
          @pod = Pod.first(:name => name)
        end
        describe 'with newly created version' do
          before do
            @version = PodVersion.create(:pod => @pod, :name => version_name)
          end
          it 'only triggers version and spec' do
            expect_events :version_created, :spec_updated
            add_commit @version
          end
          describe 'that was loaded from the DB' do
            before do
              @version = PodVersion.first(:name => version_name)
            end
            it 'only triggers a spec update' do
              expect_events :spec_updated
              add_commit @version
            end
          end
        end
      end
      describe 'with newly created version' do
        before do
          @version = PodVersion.create(:pod => @pod, :name => version_name)
        end
        it 'triggers all events' do
          expect_events :pod_created, :version_created, :spec_updated
          add_commit @version
        end
        describe 'that was loaded from the DB' do
          before do
            @version = PodVersion.first(:name => version_name)
          end
          # This is an unusual event, but it can occur.
          #
          it 'only triggers a spec update' do
            expect_events :spec_updated
            add_commit @version
          end
        end
      end
    end
  end
end
