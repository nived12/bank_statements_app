class AddFilePasswordToStatementFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :statement_files, :file_password, :text
  end
end
