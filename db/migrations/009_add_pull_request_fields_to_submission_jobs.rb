Sequel.migration do
  up do
    alter_table :submission_jobs do
      add_column :specification_data,  :text
      add_column :base_commit_sha,     :varchar
      add_column :base_tree_sha,       :varchar
      add_column :new_commit_sha,      :varchar
      add_column :new_tree_sha,        :varchar
      add_column :new_branch_ref,      :varchar
      add_column :pull_request_number, :integer
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :specification_data
      drop_column :base_commit_sha
      drop_column :base_tree_sha
      drop_column :new_commit_sha
      drop_column :new_tree_sha
      drop_column :new_branch_ref
      drop_column :pull_request_number
    end
  end
end

