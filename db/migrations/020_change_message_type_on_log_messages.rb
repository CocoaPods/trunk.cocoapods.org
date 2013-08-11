Sequel.migration do
  up do
    alter_table :log_messages do
      set_column_type :message, :text
    end
  end

  down do
    alter_table :log_messages do
      set_column_type :message, :varchar
    end
  end
end
