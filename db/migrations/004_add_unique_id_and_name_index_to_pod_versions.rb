Sequel.migration do
  change do
    alter_table :pod_versions do
      drop_index [:pod_id, :name]
      add_index [:pod_id, :name], :unique => true
    end
  end
end
