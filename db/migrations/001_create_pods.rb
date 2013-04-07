Sequel.migration do
  up do
    create_table :pods do
      primary_key :id

      column :name,       :varchar,   :empty => false
      column :created_at, :timestamp
      column :updated_at, :timestamp

      index :name
    end
  end

  down do
    drop_table :pods
  end
end

