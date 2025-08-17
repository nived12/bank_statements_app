class AddCascadeDeleteToStatementFinancialSummaries < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing foreign key constraint
    remove_foreign_key :statement_financial_summaries, :statement_files

    # Add the foreign key constraint with cascade delete
    add_foreign_key :statement_financial_summaries, :statement_files, on_delete: :cascade
  end
end
