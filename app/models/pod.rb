require 'app/models/pod_version'

module Pod
  module TrunkApp
    class Pod < Sequel::Model
      self.dataset = :pods
      plugin :timestamps

      one_to_many :versions, :class => 'Pod::TrunkApp::PodVersion'
      many_to_many :owners

      def self.find_by_name_and_owner(name, owner, create_if_non_existing = false)
        if pod = find(:name => name)
          pod if pod.owners.include?(owner)
        elsif create_if_non_existing
          owner.add_pod(:name => name)
        end
      end
    end
  end
end
