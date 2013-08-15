Sequel.migration do
  up do
    alter_table :sessions do
      add_column :verification_token, :varchar, :empty => false
      add_index :verification_token
    end
  end

  down do
    alter_table :sessions do
      drop_column :verification_token
    end
  end
end

