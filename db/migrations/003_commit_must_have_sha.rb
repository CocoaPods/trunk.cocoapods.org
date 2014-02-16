Sequel.migration do
  change do
    alter_table :commits do
      set_column_not_null :sha
    end
  end
end
