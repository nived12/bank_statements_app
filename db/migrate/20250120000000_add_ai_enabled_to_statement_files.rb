class AddAiEnabledToStatementFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :statement_files, :ai_enabled, :boolean, default: true, null: false
  end
end
