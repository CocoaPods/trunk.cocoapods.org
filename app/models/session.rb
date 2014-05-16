require 'token'
require 'app/models/owner'

module Pod
  module TrunkApp
    class Session < Sequel::Model
      TOKEN_LENGTH = 32             # characters
      VERIFICATION_TOKEN_LENGTH = 8 # characters
      VALIDITY_LENGTH = 128         # days

      self.dataset = :sessions
      plugin :timestamps
      plugin :validation_helpers
      plugin :after_initialize

      many_to_one :owner

      subset(:valid) { valid_until > Time.current }
      subset(:verified, :verified => true)

      alias_method :verified?, :verified

      def after_initialize
        super
        if new?
          self.verified = false
          self.valid_for = VALIDITY_LENGTH unless valid_until
          self.token ||= Token.generate(TOKEN_LENGTH) { |t| Session.find(:token => t) }
          self.verification_token ||= Token.generate(VERIFICATION_TOKEN_LENGTH) { |t| Session.find(:verification_token => t) }
        end
      end

      def public_attributes
        {
          'created_at' => created_at,
          'valid_until' => valid_until,
          'verified' => verified,
          'created_from_ip' => created_from_ip,
          'description' => description,
        }
      end

      def to_json(*a)
        public_attributes.to_json(*a)
      end

      def valid_for=(duration_in_days)
        self.valid_until = duration_in_days.days.from_now
      end

      def verify!
        raise 'Unable to verify an already verified token.' if verified
        update(:verified => true, :verification_token => nil)
      end

      def prolong!
        raise 'Unable to prolong an invalid/unverified session.' unless active?
        update(:valid_for => VALIDITY_LENGTH)
      end

      def active?
        verified && valid_until > Time.current
      end

      def self.with_token(token)
        return if token.nil?
        valid.verified.where(:token => token).first
      end

      def self.with_verification_token(token)
        return if token.nil?
        valid.where(:verification_token => token).first
      end

      protected

      def validate
        super
        validates_presence :owner_id
        validates_presence :created_from_ip
      end
    end
  end
end
