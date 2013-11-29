Sequel.migration do
  change do
    alter_table :submission_jobs do
      add_column :new_commit_url, :varchar
    end
  end
end
