class ChangeParsedJsonToTextOnStatementFiles < ActiveRecord::Migration[8.0]
  def up
    change_column :statement_files, :parsed_json, :text
  end

  def down
    change_column :statement_files, :parsed_json, :jsonb, using: 'parsed_json::jsonb'
  end
end
