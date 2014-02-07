Sequel.migration do
  change do
    [:pods, :pod_versions, :submission_jobs, :log_messages, :owners, :sessions].each do |table|
      alter_table :pods do
        set_column_not_null :created_at
      end
    end
  end
end

