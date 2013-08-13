Sequel.migration do
  up do
    create_table :owners do
      primary_key :id

      column :email,       :varchar,   :empty => false
      column :name,        :varchar
      column :created_at,  :timestamp

      index :email
    end
  end

  down do
    drop_table :owners
  end
end
