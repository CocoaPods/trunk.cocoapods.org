Sequel.migration do
  change do
    alter_table :pod_versions do
      drop_column :url
    end
  end
end
