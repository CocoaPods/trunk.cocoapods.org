Sequel.migration do
  up do
    alter_table :pod_versions do
      add_column :published, :boolean, :default => false
    end
  end

  down do
    alter_table :pod_versions do
      drop_column :published
    end
  end
end

