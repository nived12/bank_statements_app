class CreateStatementFinancialSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :statement_financial_summaries do |t|
      t.references :statement_file, null: false, foreign_key: true
      t.string :statement_type, null: false  # 'savings', 'credit', 'payroll'

      # Common fields across ALL statement types
      t.decimal :initial_balance, precision: 12, scale: 2
      t.decimal :final_balance, precision: 12, scale: 2
      t.date :statement_period_start
      t.date :statement_period_end
      t.integer :days_in_period
      t.decimal :total_commissions, precision: 12, scale: 2
      t.decimal :total_fees, precision: 12, scale: 2

      # Type-specific JSON data
      t.json :statement_type_data, null: false

      t.timestamps

      t.index :statement_type
      t.index [ :statement_type, :statement_period_start ]
    end
  end
end
