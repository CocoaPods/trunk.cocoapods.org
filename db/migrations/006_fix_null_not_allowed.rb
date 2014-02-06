Sequel.migration do
  change do
    alter_table :pods do
      set_column_not_null :name
    end
    alter_table :pod_versions do
      set_column_not_null :name
    end
    alter_table :log_messages do
      set_column_not_null :message
    end
    alter_table :owners do
      set_column_not_null :email
      set_column_not_null :name
    end
    alter_table :sessions do
      set_column_not_null :token
    end
  end
end

