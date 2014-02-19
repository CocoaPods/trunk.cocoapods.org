Sequel.migration do
  change do
    alter_table :commits do
      drop_constraint :sha, :type => :unique
      add_unique_constraint [:pod_version_id, :sha]
    end
  end
end

