require 'app/models/owner'

require 'peiji_san'

module Pod
  module TrunkApp
    class Dispute < Sequel::Model
      self.dataset = :disputes

      extend PeijiSan
      plugin :timestamps
      plugin :validation_helpers

      many_to_one :claimer, :class => 'Pod::TrunkApp::Owner'

      alias_method :settled?, :settled

      protected

      def validate
        super
        validates_presence :claimer_id
        validates_presence :message
      end
    end
  end
end
