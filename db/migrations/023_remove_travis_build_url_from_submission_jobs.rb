Sequel.migration do
  up do
    alter_table :submission_jobs do
      drop_column :travis_build_url
    end
  end

  down do
    alter_table :submission_jobs do
      add_column :travis_build_url, :varchar
    end
  end
end
