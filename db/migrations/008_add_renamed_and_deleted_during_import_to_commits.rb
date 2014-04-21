Sequel.migration do
  change do
    alter_table :commits do
      add_column :renamed_file_during_import, :boolean, :default => false
      add_column :deleted_file_during_import, :boolean, :default => false
    end
  end
end
