Sequel.migration do
  up do
    alter_table :submission_jobs do
      add_column :travis_build_id, :integer, :default => nil
    end
  end

  down do
    alter_table :submission_jobs do
      drop_column :travis_build_id
    end
  end
end

