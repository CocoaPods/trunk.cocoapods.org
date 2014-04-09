Sequel.migration do
  change do
    alter_table :log_messages do
      add_column :reference, :varchar
    end
  end
end
