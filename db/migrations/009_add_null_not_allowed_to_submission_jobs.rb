Sequel.migration do
  change do
    alter_table :submission_jobs do
      set_column_not_null :owner_id
      set_column_not_null :specification_data
    end
  end
end

