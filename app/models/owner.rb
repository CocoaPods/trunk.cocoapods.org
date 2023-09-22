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

      one_to_many :sessions, :order => Sequel.asc(:created_at)
      many_to_many :pods

      UNCLAIMED_OWNER_EMAIL = 'unclaimed-pods@cocoapods.org'

      # This is the owner that was initially assigned to all imported pods when we switched to the
      # use of the trunk app.
      #
      def self.unclaimed
        first(:email => UNCLAIMED_OWNER_EMAIL)
      end

      def self.find_by_email(email)
        first(:email => normalize_email(email))
      end

      def self.find_or_initialize_by_email_and_name(email, name)
        Owner.find_by_email(email) || Owner.new(:email => email, :name => name)
      end

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

      def email=(email)
        super(self.class.normalize_email(email))
      end

      def name=(name)
        super(name ? name.strip : nil)
      end

      def after_create
        super
        @was_created = true
      end

      def create_session!(from_ip, confirmation_url_template, session_description = nil)
        session = add_session(:created_from_ip => from_ip, :description => session_description)
        was_created = @was_created
        confirmation_url = confirmation_url_template % session.verification_token

        mail = Mail.new
        mail.charset = 'UTF-8'
        mail.from    = 'no-reply@cocoapods.org'
        mail.to      = email
        mail.subject = @was_created ? '[CocoaPods] Confirm your registration.' : '[CocoaPods] Confirm your session.'
        mail.body    = ERB.new(File.read(File.join(ROOT, 'app/views/mailer/create_session.erb'))).result(binding)
        mail.deliver

        session
      end

      protected

      def validate
        super
        validates_presence :name
        validates_format RFC822::EMAIL, :email, :message => 'has invalid format'
        validates_mx_records :email
      end

      def validates_mx_records(attr)
        unless ValidMXRecords.valid_mx_records?(send(attr))
          errors.add(:email, 'has unverifiable domain')
        end
      end
    end
  end
end
