Sequel.migration do
  up do
    alter_table :submission_jobs do
      add_column :deleted_branch, :boolean, :default => nil
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :deleted_branch
    end
  end
end

