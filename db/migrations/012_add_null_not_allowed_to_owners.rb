Sequel.migration do
  change do
    alter_table :owners do
      set_column_not_null :email
    end
  end
end

