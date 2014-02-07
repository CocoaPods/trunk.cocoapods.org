Sequel.migration do
  change do
    alter_table :sessions do
      set_column_not_null :owner_id
      set_column_not_null :verification_token
      set_column_not_null :verified
      set_column_not_null :valid_until
    end
  end
end

