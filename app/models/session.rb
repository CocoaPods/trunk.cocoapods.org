require 'token'

require 'app/models/owner'

module Pod
  module PushApp
    class Session < Sequel::Model
      SECONDS_IN_DAY = 3600 * 24

      DEFAULT_TOKEN_LENGTH = 32 # characters
      DEFAULT_VALIDITY_LENGTH = 128 # days

      self.dataset = :owners
      plugin :timestamps

      many_to_one :owner, :class => 'Pod::PushApp::Owner'

      attr_accessor :token_length
      attr_reader :valid_for

      def after_initialize
        super
        set_defaults
      end

      def valid_for=(duration_in_days)
        @valid_for = duration_in_days
        self.valid_until = Time.now + (duration_in_days * SECONDS_IN_DAY)
      end

      private

      def set_defaults
        if new?
          self.valid_for ||= DEFAULT_VALIDITY_LENGTH
          self.token_length ||= DEFAULT_TOKEN_LENGTH
          set_token
        end
      end

      def set_token
        self.token = Token.generate(:length => token_length)
      end
    end
  end
end
