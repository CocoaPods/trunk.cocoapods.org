Sequel.migration do
  change do
    alter_table :pods do
      drop_index :name
      add_index :name, :unique => true
    end
  end
end
