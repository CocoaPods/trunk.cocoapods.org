Sequel.migration do
  up do
    alter_table :sessions do
      add_column :verified, :boolean, :default => false
    end
  end

  down do
    alter_table :sessions do
      drop_column :verified
    end
  end
end

