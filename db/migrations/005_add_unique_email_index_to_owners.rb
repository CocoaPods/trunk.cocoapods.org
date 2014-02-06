Sequel.migration do
  change do
    alter_table :owners do
      drop_index :email
      add_index :email, :unique => true
    end
  end
end

