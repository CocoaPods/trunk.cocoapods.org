Sequel.migration do
  change do
    alter_table :log_messages do
      add_column :data, String, :text => true
    end
  end
end
