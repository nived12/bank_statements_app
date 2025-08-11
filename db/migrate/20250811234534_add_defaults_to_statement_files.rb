class AddDefaultsToStatementFiles < ActiveRecord::Migration[8.0]
  def up
    # Set column defaults
    change_column_default :statement_files, :parsed_json, from: nil, to: {}
    change_column_default :statement_files, :redaction_map, from: nil, to: {}

    # Update existing data
    execute "UPDATE statement_files SET parsed_json = '{}'::jsonb WHERE parsed_json IS NULL"
    execute "UPDATE statement_files SET redaction_map = '{}'::jsonb WHERE redaction_map IS NULL"
  end

  def down
    # Remove column defaults
    change_column_default :statement_files, :parsed_json, from: {}, to: nil
    change_column_default :statement_files, :redaction_map, from: {}, to: nil

    # Revert data changes
    execute "UPDATE statement_files SET parsed_json = NULL WHERE parsed_json = '{}'::jsonb"
    execute "UPDATE statement_files SET redaction_map = NULL WHERE redaction_map = '{}'::jsonb"
  end
end
