require 'app/models/pod'
require 'app/models/session'

require 'erb'
require 'rfc822'

module Pod
  module TrunkApp
    class Owner < Sequel::Model
      self.dataset = :owners

      plugin :timestamps
      plugin :validation_helpers

      one_to_many :sessions
      many_to_many :pods

      def public_attributes
        attributes = { 'created_at' => created_at, 'email' => email }
        attributes['name'] = name if name
        attributes
      end

      def to_json(*a)
        public_attributes.to_json(*a)
      end

      def self.normalize_email(email)
        email.to_s.strip.downcase
      end

      def self.find_by_email(email)
        first(:email => normalize_email(email))
      end

      def email=(email)
        super(self.class.normalize_email(email))
      end

      def after_create
        super
        @was_created = true
      end

      def create_session!(confirmation_url_template)
        session = add_session({})
        was_created = @was_created
        confirmation_url = confirmation_url_template % session.verification_token

        mail = Mail.new
        mail.charset = 'UTF-8'
        mail.from    = 'info@cocoapods.org'
        mail.to      = email
        mail.subject = @was_created ? '[CocoaPods] Confirm your registration.' : '[CocoaPods] Confirm your session.'
        mail.body    = ERB.new(File.read(File.join(ROOT, 'app/views/mailer/create_session.erb'))).result(binding)
        mail.deliver!

        session
      end

      protected

      def validate
        super
        validates_presence :name
        validates_format RFC822::EMAIL, :email
      end
    end
  end
end
