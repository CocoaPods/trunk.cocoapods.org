require 'app/models/pod_version'

module Pod
  module PushApp
    class Pod < Sequel::Model
      self.dataset = :pods
      plugin :timestamps

      one_to_many :versions, :class => 'Pod::PushApp::PodVersion'
    end
  end
end
