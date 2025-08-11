class AddRedactionFieldsToStatementFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :statement_files, :redaction_map, :text
    add_column :statement_files, :redaction_hmac, :string
    add_index  :statement_files, :redaction_hmac
  end
end
