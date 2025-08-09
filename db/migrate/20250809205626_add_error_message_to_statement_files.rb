class AddErrorMessageToStatementFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :statement_files, :error_message, :text
  end
end
