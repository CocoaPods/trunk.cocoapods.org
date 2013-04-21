Sequel.migration do
  up do
    create_table :submission_jobs do
      primary_key :id
      foreign_key :pod_version_id, :pod_versions

      column :created_at, :timestamp
      column :updated_at, :timestamp
    end
  end

  down do
    drop_table :submission_jobs
  end
end

