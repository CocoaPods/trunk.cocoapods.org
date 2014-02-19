Sequel.migration do
  change do
    alter_table :commits do
      add_unique_constraint :sha
    end
  end
end
