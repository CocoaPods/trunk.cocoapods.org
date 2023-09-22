require 'app/models/owner'

module Pod
  module TrunkApp
    class Dispute < Sequel::Model
      self.dataset = :disputes
      self.dataset = dataset.extension(:pagination)

      plugin :timestamps
      plugin :validation_helpers

      many_to_one :claimer, :class => 'Pod::TrunkApp::Owner'

      alias settled? settled

      protected

      def validate
        super
        validates_presence :claimer_id
        validates_presence :message
      end
    end
  end
end
