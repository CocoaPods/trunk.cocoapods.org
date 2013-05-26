Sequel.migration do
  up do
    alter_table :submission_jobs do
      drop_column :specification_data
    end
    alter_table :pod_versions do
      add_column :specification_data, :text
    end
  end

  down do
    alter_table :pod_versions do
      drop_column :specification_data
    end
    alter_table :submission_jobs do
      add_column :specification_data, :text
    end
  end
end

