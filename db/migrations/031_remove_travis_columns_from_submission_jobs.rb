Sequel.migration do
  up do
    alter_table :submission_jobs do
      drop_column :travis_build_success
      drop_column :travis_build_id
    end
  end

  down do
    alter_table :submission_jobs do
      add_column :travis_build_success, :boolean, :default => nil
      add_column :travis_build_id, :integer
    end
  end
end

