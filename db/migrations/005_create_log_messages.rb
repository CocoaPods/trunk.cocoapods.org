Sequel.migration do
  up do
    create_table :log_messages do
      primary_key :id
      foreign_key :submission_job_id, :submission_jobs

      column :message,    :varchar,   :empty => false
      column :created_at, :timestamp
      column :updated_at, :timestamp
    end
  end

  down do
    drop_table :log_messages
  end
end

