require 'erb'

module Pod
  module TrunkApp
    class Owner < Sequel::Model
      self.dataset = :owners
      plugin :timestamps

      one_to_many :sessions, :class => 'Pod::TrunkApp::Session'

      def public_attributes
        { 'created_at' => created_at, 'id' => id, 'email' => email, 'name' => name }
      end

      def to_yaml
        public_attributes.to_yaml
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
    end
  end
end
