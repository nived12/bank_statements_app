class MakeStatementFileIdOptionalInTransactions < ActiveRecord::Migration[8.0]
  def change
    change_column_null :transactions, :statement_file_id, true
  end
end
