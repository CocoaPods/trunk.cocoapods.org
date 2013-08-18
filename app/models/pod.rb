require 'app/models/pod_version'

module Pod
  module TrunkApp
    class Pod < Sequel::Model
      self.dataset = :pods
      plugin :timestamps

      one_to_many :versions, :class => 'Pod::TrunkApp::PodVersion'
      many_to_many :owners
    end
  end
end
