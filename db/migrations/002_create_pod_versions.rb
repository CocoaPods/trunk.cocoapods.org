Sequel.migration do
  up do
    create_table :pod_versions do
      primary_key :id
      foreign_key :pod_id, :pods

      column :name,       :varchar,   :empty => false
      column :created_at, :timestamp
      column :updated_at, :timestamp

      index [:pod_id, :name]
    end
  end

  down do
    drop_table :pod_versions
  end
end

