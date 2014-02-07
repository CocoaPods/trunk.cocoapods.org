Sequel.migration do
  change do
    alter_table :pod_versions do
      set_column_not_null :pod_id
    end
  end
end

