Sequel.migration do
  up do
    create_table :sessions do
      primary_key :id
      foreign_key :owner_id, :owners

      column :token,       :varchar,   :empty => false
      column :valid_until, :timestamp
      column :created_at,  :timestamp

      index :token
    end
  end

  down do
    drop_table :sessions
  end
end
