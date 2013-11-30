Sequel.migration do
  change do
    alter_table :pod_versions do
      add_column :data_url, :varchar
    end
  end
end

