Sequel.migration do
  change do
    alter_table :submission_jobs do
      drop_column :base_commit_sha
      drop_column :base_tree_sha
      drop_column :new_tree_sha
      drop_column :needs_to_perform_work
      drop_column :attempts
      drop_column :new_commit_url
      rename_column :new_commit_sha, :commit_sha
    end
  end
end

