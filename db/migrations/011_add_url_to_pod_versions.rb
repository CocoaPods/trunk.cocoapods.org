Sequel.migration do
  up do
    alter_table :pod_versions do
      add_column :url, :varchar
    end
  end

  down do
    alter_table :pod_versions do
      drop_column :url
    end
  end
end

