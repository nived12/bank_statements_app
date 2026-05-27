class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :statement_files,
      "user_id, COALESCE(cutoff_date, created_at) DESC",
      name: "index_statement_files_on_user_id_and_effective_date"

    add_index :statement_files, [:user_id, :created_at],
      name: "index_statement_files_on_user_id_and_created_at"

    add_index :savings, [:user_id, :status, :created_at],
      name: "index_savings_on_user_id_and_status_and_created_at"

    add_index :debts, [:user_id, :status, :created_at],
      name: "index_debts_on_user_id_and_status_and_created_at"
  end
end
