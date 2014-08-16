module Pod
  module TrunkApp
    class Pod < Sequel::Model
      self.dataset = :pods

      def name=(name)
        self.normalized_name = name.downcase if name
        super
      end
    end
  end
end

Sequel.migration do
  transaction
  up do
    Pod::TrunkApp::Pod.dataset.use_cursor.each do |pod|
      pod.name = pod.name
      pod.save(:validate => false)
    end
  end
end
