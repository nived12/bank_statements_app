class RemoveFileHashFromStatementFiles < ActiveRecord::Migration[8.0]
  def change
    remove_column :statement_files, :file_hash, :string if column_exists?(:statement_files, :file_hash)
  end
end
