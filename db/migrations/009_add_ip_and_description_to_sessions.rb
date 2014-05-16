Sequel.migration do
  change do
    alter_table :sessions do
      add_column :created_from_ip, :varchar, :null => false
      add_column :description, :varchar
    end
  end
end
