require 'app/controllers/slack_controller'

module Pod
  module TrunkApp
    module SlackController
      SLACK_API_URL = 'https://cocoapods.slack.com/services/hooks/' \
        "incoming-webhook?token=#{ENV['SLACK_DISPUTE_TOKEN']}"

      def self.notify_slack_of_new_dispute(dispute)
        link = "https://trunk.cocoapods.org/manage/disputes/#{dispute.id}"
        send_to_slack(:attachments => [{
                        :fallback => "New dispute on trunk [Urgent]: <#{link}>",
                        :pretext => "There's a new dispute on trunk [Urgent]: <#{link}>",
                        :color => :warning,
                        :fields => [{
                          :title => 'Dispute by ' \
                            "#{dispute.claimer.name} (#{dispute.claimer.email})",
                          :value => dispute.message,
                          :short => false,
                        }],
                      }])
      end

      def self.notify_slack_of_resolved_dispute(dispute)
        link = "https://trunk.cocoapods.org/manage/disputes/#{dispute.id}"
        send_to_slack(:attachments => [{
                        :fallback => "Settled dispute on trunk: <#{link}>",
                        :pretext => "There's a settled dispute on trunk: <#{link}>",
                        :color => :warning,
                        :fields => [{
                          :title => 'Dispute by ' \
                            "#{dispute.claimer.name} (#{dispute.claimer.email})",
                          :value => 'Settled',
                          :short => false,
                        }],
                      }])
      end

      def self.send_to_slack(data)
        REST.post(SLACK_API_URL, data.to_json)
      rescue REST::Error
        "RuboCop: If REST has problems POSTing to Slack, we don't care."
      end
    end
  end
end
