Sequel.migration do
  change do
    alter_table :commits do
      add_column :imported, :boolean, :default => false
    end
  end
end
