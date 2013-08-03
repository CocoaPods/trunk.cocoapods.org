Sequel.migration do
  up do
    alter_table :submission_jobs do
      add_column :attempts, :integer, :default => 1
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :attempts
    end
  end
end

