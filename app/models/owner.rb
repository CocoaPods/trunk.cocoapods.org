module Pod
  module PushApp
    class Owner < Sequel::Model
      self.dataset = :owners
      plugin :timestamps

      one_to_many :sessions, :class => 'Pod::PushApp::Session'
    end
  end
end
