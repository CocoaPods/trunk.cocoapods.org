Sequel.migration do
  up do
    alter_table :submission_jobs do
      drop_column :new_branch_ref
      drop_column :pull_request_number
      drop_column :merge_commit_sha
      drop_column :deleted_branch
    end
  end

  down do
    alter_table :submission_jobs do
      add_column :new_branch_ref, :varchar
      add_column :pull_request_number, :integer
      add_column :merge_commit_sha, :varchar
      add_column :deleted_branch, :boolean, :default => nil
    end
  end
end
