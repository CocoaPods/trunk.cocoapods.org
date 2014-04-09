Sequel.migration do
  change do
    alter_table :disputes do
      add_column :settled, :boolean, :default => false
    end
  end
end
