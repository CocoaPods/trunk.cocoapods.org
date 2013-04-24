Sequel.migration do
  up do
    alter_table :pod_versions do
      drop_column :state
    end
  end

  down do
    alter_table :pod_versions do
      add_column :state, :varchar, :default => nil
    end
  end
end

