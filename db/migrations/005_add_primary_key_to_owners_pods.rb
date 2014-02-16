Sequel.migration do
  change do
    alter_table :owners_pods do
      add_primary_key [:owner_id, :pod_id] # Also ensures we don't insert duplicate associations.
    end
  end
end
