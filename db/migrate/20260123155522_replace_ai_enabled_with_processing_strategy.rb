class ReplaceAiEnabledWithProcessingStrategy < ActiveRecord::Migration[8.0]
  def up
    add_column :statement_files, :processing_strategy, :string, default: 'parser_only', null: false

    # Migrate existing data
    StatementFile.where(ai_enabled: true).update_all(processing_strategy: 'text_with_ai')
    StatementFile.where(ai_enabled: false).update_all(processing_strategy: 'parser_only')

    remove_column :statement_files, :ai_enabled
  end

  def down
    add_column :statement_files, :ai_enabled, :boolean, default: false, null: false

    StatementFile.where(processing_strategy: 'parser_only').update_all(ai_enabled: false)
    StatementFile.where.not(processing_strategy: 'parser_only').update_all(ai_enabled: true)

    remove_column :statement_files, :processing_strategy
  end
end
