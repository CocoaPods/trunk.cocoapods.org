require 'token'

require 'app/models/owner'

module Pod
  module PushApp
    class Session < Sequel::Model
      self.dataset = :owners
      plugin :timestamps

      many_to_one :owner, :class => 'Pod::PushApp::Owner'
    end
  end
end
