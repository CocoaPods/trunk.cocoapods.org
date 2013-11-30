Sequel.migration do
  change do
    alter_table :pod_versions do
      add_column :commit_sha, :varchar
    end
  end
end

