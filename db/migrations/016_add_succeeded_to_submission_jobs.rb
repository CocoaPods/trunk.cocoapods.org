Sequel.migration do
  up do
    alter_table :submission_jobs do
      add_column :succeeded, :boolean, :default => nil
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :succeeded
    end
  end
end

