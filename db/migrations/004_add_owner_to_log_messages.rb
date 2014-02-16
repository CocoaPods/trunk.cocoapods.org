Sequel.migration do
  change do
    alter_table :log_messages do
      add_foreign_key :owner_id, :owners, :null=>true, :key=>[:id]
    end
  end
end
