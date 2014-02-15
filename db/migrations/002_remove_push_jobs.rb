Sequel.migration do
  change do
    alter_table(:log_messages) do
      drop_column :push_job_id
      add_column :pod_version_id, Integer
      add_foreign_key [:pod_version_id], :pod_versions, :name=>:log_messages_pod_version_id_fkey, :key=>[:id]
    end

    drop_table :push_jobs
  end
end
