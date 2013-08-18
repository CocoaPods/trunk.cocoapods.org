Sequel.migration do
  change do
    create_table :owners_pods do
      foreign_key :owner_id, :owners
      foreign_key :pod_id, :pods
    end
  end
end
