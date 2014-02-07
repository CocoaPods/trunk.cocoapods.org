Sequel.migration do
  change do
    alter_table :log_messages do
      set_column_not_null :submission_job_id
      set_column_not_null :message
    end
  end
end

