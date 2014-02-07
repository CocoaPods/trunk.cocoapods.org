Sequel.migration do
  change do
    alter_table :submission_jobs do
      set_column_not_null :pod_version_id
    end
  end
end

