Sequel.migration do
  up do
    alter_table :submission_jobs do
      add_column :merge_commit_sha, :varchar
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :merge_commit_sha
    end
  end
end


