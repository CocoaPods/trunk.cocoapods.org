Sequel.migration do
  change do
    alter_table :pods do
      add_column :deleted, :boolean, :default => false
    end
  end
end
