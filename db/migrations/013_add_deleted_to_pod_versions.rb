Sequel.migration do
  change do
    alter_table :pod_versions do
      add_column :deleted, :boolean, :default => false
    end
  end
end
