class ChangeParsedJsonAndRedactionMapToJson < ActiveRecord::Migration[8.0]
  def up
    change_column :statement_files, :parsed_json, :jsonb, using: 'parsed_json::jsonb'
    change_column :statement_files, :redaction_map, :jsonb, using: 'redaction_map::jsonb'
  end

  def down
    change_column :statement_files, :parsed_json, :text
    change_column :statement_files, :redaction_map, :text
  end
end
