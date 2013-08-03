Sequel.migration do
  up do
    alter_table :submission_jobs do
      drop_column :state
      add_column :needs_to_perform_work, :boolean, :default => true
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :needs_to_perform_work
      add_column :state, :varchar, :default => 'submitted'
    end
  end
end

