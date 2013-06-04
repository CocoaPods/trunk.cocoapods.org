require 'token'

require 'app/models/owner'

module Pod
  module PushApp
    class Session < Sequel::Model
      DEFAULT_TOKEN_LENGTH = 32 # characters

      self.dataset = :owners
      plugin :timestamps

      many_to_one :owner, :class => 'Pod::PushApp::Owner'

      attr_accessor :token_length

      def after_initialize
        super
        set_defaults
      end

      private

      def set_defaults
        if new?
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
