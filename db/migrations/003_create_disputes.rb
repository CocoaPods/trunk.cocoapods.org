Sequel.migration do
  change do
    create_table :disputes do
      primary_key :id
      foreign_key :claimer_id, :owners, :null => false
      String :message, :text => true, :null => false
    end
  end
end
