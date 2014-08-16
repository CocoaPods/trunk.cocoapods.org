Sequel.migration do
  change do
    alter_table :pods do
      add_column :normalized_name, :varchar
    end
  end
end
