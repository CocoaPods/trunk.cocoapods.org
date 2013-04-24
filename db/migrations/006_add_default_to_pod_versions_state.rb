Sequel.migration do
  up do
    alter_table :pod_versions do
      set_column_default :state, 'submitted'
    end
  end

  down do
    alter_table :pod_versions do
      set_column_default :state, nil
    end
  end
end


