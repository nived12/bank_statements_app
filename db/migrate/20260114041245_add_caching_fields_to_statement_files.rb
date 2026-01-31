class AddCachingFieldsToStatementFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :statement_files, :file_hash, :string
    add_column :statement_files, :usage_metadata, :jsonb, default: {}

    add_index :statement_files, :file_hash
  end
end
