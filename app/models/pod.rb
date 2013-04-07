module Pod
  module PushApp
    class Pod < Sequel::Model
      self.dataset = :pods
      plugin :timestamps

      def self.find_or_create_by_name(name)
        find_or_create(:name => name)
      end
    end
  end
end
