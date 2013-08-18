Sequel.migration do
  change do
    alter_table :pod_versions do
      add_foreign_key :published_by_submission_job_id, :submission_jobs
    end
  end
end

