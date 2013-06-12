module Pod
  module PushApp
    class Owner < Sequel::Model
      self.dataset = :owners
      plugin :timestamps

      one_to_many :sessions, :class => 'Pod::PushApp::Session'

      def attributes
        values.inject({}) do |hash, (key, value)|
          hash[key.to_s] = value
          hash
        end
      end

      def public_attributes
        attributes
      end

      def to_yaml
        public_attributes.to_yaml
      end

      def self.normalize_email(email)
        email.to_s.strip.downcase
      end

      def self.find_or_create_by_email(email)
        email = normalize_email(email)
        if owner = where('email = ?', email).first
          owner
        else
          create(:email => email)
        end
      end
    end
  end
end
