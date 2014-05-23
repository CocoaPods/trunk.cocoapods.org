require File.expand_path('../../spec_helper', __FILE__)

require 'webhook'

describe 'Webhook' do

  it 'is enabled correctly' do
    Webhook.enabled?.should == false
    Webhook.enable
    Webhook.enabled?.should == true
    Webhook.disable
    Webhook.enabled?.should == false
    Webhook.enable
    Webhook.enabled?.should == true
    Webhook.disable
  end

  describe 'with webhook enabled' do
    before do
      Webhook.enable
    end
    after do
      Webhook.disable
    end

    it 'does not take long to send a message' do
      Webhook.pod_created = ['some url']

      # Measure time waiting for webhook (blocks).
      #
      t = Time.now
      Webhook.call('pod', 'create', 'hello')
      duration = Time.now - t

      duration.should < 0.01
    end

    describe 'convenience methods' do
      describe 'with URLs' do
        before do
          @time = Time.parse('2001-01-01 00:00:00 UTC')
          Webhook.pod_created = %w(pod_created_url1 pod_created_url2)
          Webhook.version_created = %w(version_created_url1 version_created_url2)
          Webhook.spec_updated = %w(spec_updated_url1 spec_updated_url2)
        end
        after do
          Webhook.pod_created = []
          Webhook.version_created = []
          Webhook.spec_updated = []
        end
        it 'pod_created calls call correctly' do
          Webhook.expects(:write_child).once.with(
            %Q(pod;create;{"type":"pod","action":"create","timestamp":"2001-01-01 00:00:00 ) +
            %Q(UTC","data_url":"some_url"};pod_created_url1,pod_created_url2\n)
          )
          Webhook.pod_created(@time, 'some_url')
        end
        it 'version_created calls call correctly' do
          Webhook.expects(:write_child).once.with(
            %Q(version;create;{"type":"version","action":"create","timestamp":"2001-01-01 00:00:00 ) +
            %Q(UTC","data_url":"some_url"};version_created_url1,version_created_url2\n)
          )
          Webhook.version_created(@time, 'some_url')
        end
        it 'spec_updated calls call correctly' do
          Webhook.expects(:write_child).once.with(
            %Q(spec;update;{"type":"spec","action":"update","timestamp":"2001-01-01 00:00:00 ) +
            %Q(UTC","data_url":"some_url"};spec_updated_url1,spec_updated_url2\n)
          )
          Webhook.spec_updated(@time, 'some_url')
        end
      end
      describe 'without URLs' do
        before do
          @time = Time.parse('2001-01-01 00:00:00 +0000')
          Webhook.pod_created = []
          Webhook.version_created = []
          Webhook.spec_updated = []
        end
        it 'pod_created calls call correctly' do
          Webhook.expects(:write_child).never
          Webhook.pod_created(@time, 'some_url')
        end
        it 'version_created calls call correctly' do
          Webhook.expects(:write_child).never
          Webhook.version_created(@time, 'some_url')
        end
        it 'spec_updated calls call correctly' do
          Webhook.expects(:write_child).never
          Webhook.spec_updated(@time, 'some_url')
        end
      end
    end
  end

end
