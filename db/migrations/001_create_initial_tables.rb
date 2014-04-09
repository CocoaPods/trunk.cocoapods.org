Sequel.migration do
  change do
    create_table(:owners, :ignore_index_errors => true) do
      primary_key :id
      String :email, :size => 255, :null => false
      String :name, :size => 255, :null => false
      DateTime :created_at
      DateTime :updated_at

      index [:email], :unique => true
    end

    create_table(:pods, :ignore_index_errors => true) do
      primary_key :id
      String :name, :size => 255, :null => false
      DateTime :created_at, :null => false
      DateTime :updated_at

      index [:name], :unique => true
    end

    # create_table(:schema_info) do
      # Integer :version, :default=>0, :null=>false
    # end

    create_table(:owners_pods) do
      foreign_key :owner_id, :owners, :null => false, :key => [:id]
      foreign_key :pod_id, :pods, :null => false, :key => [:id]

      primary_key [:owner_id, :pod_id]
    end

    create_table(:pod_versions, :ignore_index_errors => true) do
      primary_key :id
      String :name, :size => 255, :null => false
      DateTime :created_at
      DateTime :updated_at
      foreign_key :pod_id, :pods, :null => false, :key => [:id]

      index [:pod_id, :name], :unique => true
    end

    create_table(:sessions, :ignore_index_errors => true) do
      primary_key :id
      String :token, :size => 255, :null => false
      String :verification_token, :size => 255, :null => false
      TrueClass :verified, :default => false, :null => false
      DateTime :valid_until, :null => false
      DateTime :created_at
      DateTime :updated_at
      foreign_key :owner_id, :owners, :null => false, :key => [:id]

      index [:token], :unique => true
      index [:verification_token], :unique => true
    end

    create_table(:commits, :ignore_index_errors => true) do
      primary_key :id
      String :specification_data, :text => true, :null => false
      String :sha, :size => 255, :null => false
      DateTime :created_at
      DateTime :updated_at
      foreign_key :pod_version_id, :pod_versions, :null => false, :key => [:id]
      foreign_key :committer_id, :owners, :null => false, :key => [:id]

      index [:pod_version_id, :sha], :name => :commits_pod_version_id_sha_key, :unique => true
    end

    create_table(:log_messages) do
      primary_key :id
      String :level, :text => true, :null => false
      String :message, :text => true, :null => false
      DateTime :created_at
      DateTime :updated_at
      foreign_key :pod_version_id, :pod_versions, :key => [:id] # If this ID is null, it is a global log message.
      String :data, :text => true
      foreign_key :owner_id, :owners, :key => [:id]
    end
  end
end
