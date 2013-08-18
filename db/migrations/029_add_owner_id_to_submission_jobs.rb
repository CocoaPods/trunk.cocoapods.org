Sequel.migration do
  change do
    alter_table :submission_jobs do
      add_foreign_key :owner_id, :owners
    end
  end
end
