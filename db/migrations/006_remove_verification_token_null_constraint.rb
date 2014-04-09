Sequel.migration do
  change do
    alter_table :sessions do
      set_column_allow_null :verification_token
    end
  end
end
