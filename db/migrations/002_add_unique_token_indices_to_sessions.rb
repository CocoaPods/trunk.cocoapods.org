Sequel.migration do
  change do
    alter_table :sessions do
      drop_index :token

      add_index :token,              :unique => true
      add_index :verification_token, :unique => true
    end
  end
end
