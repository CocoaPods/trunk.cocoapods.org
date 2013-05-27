Sequel.migration do
  up do
    alter_table :submission_jobs do
      add_column :travis_build_success, :boolean, :default => nil
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :travis_build_success
    end
  end
end

