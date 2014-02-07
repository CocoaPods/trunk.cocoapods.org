# TODO
# * Add NOT NULL constraints to all timestamp fields.
# * Normalize: sequel -d DB_URL > db/migrations/001_create_initial_tables.rb
Sequel.migration do
  change do
    create_table :pods do
      primary_key :id

      column :name,               :varchar
      column :created_at,         :timestamp
      column :updated_at,         :timestamp

      index :name
    end

    create_table :pod_versions do
      primary_key :id

      column :name,               :varchar
      column :published,          :boolean,  :default => false
      column :commit_sha,         :varchar
      column :created_at,         :timestamp
      column :updated_at,         :timestamp
    end

    create_table :submission_jobs do
      primary_key :id

      column :specification_data, :text
      column :succeeded,          :boolean,  :default => nil
      column :commit_sha,         :varchar
      column :created_at,         :timestamp
      column :updated_at,         :timestamp
    end

    create_table :log_messages do
      primary_key :id

      column :message,            :text
      column :created_at,         :timestamp
      column :updated_at,         :timestamp
    end

    create_table :owners do
      primary_key :id

      column :email,              :varchar
      column :name,               :varchar
      column :created_at,         :timestamp
      column :updated_at,         :timestamp

      index :email
    end

    create_table :sessions do
      primary_key :id

      column :token,              :varchar
      column :verification_token, :varchar
      column :verified,           :boolean,  :default => false
      column :valid_until,        :timestamp
      column :created_at,         :timestamp
      column :updated_at,         :timestamp

      index :token
      #index :verification_token
    end

    # Foreign references

    alter_table :pod_versions do
      add_foreign_key :pod_id, :pods
      add_foreign_key :published_by_submission_job_id, :submission_jobs
      add_index [:pod_id, :name]
    end

    alter_table :submission_jobs do
      add_foreign_key :pod_version_id, :pod_versions
      add_foreign_key :owner_id, :owners
    end

    alter_table :log_messages do
      add_foreign_key :submission_job_id, :submission_jobs
    end

    alter_table :sessions do
      add_foreign_key :owner_id, :owners
    end

    create_table :owners_pods do
      foreign_key :owner_id, :owners
      foreign_key :pod_id, :pods
    end
  end
end
