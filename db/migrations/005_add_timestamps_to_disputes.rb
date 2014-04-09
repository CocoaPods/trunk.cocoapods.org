Sequel.migration do
  change do
    alter_table :disputes do
      add_column :created_at, DateTime, :null => false
      add_column :updated_at, DateTime
    end
  end
end
