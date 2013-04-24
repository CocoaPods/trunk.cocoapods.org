Sequel.migration do
  up do
    alter_table :pod_versions do
      drop_column :state
    end
    alter_table :submission_jobs do
      add_column :state, :varchar, :default => 'submitted'
    end
  end

  down do
    alter_table :pod_versions do
      add_column :state, :varchar, :default => 'submitted'
    end
    alter_table :submission_jobs do
      drop_column :state
    end
  end
end


