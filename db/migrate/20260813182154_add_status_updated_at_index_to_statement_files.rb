class AddStatusUpdatedAtIndexToStatementFiles < ActiveRecord::Migration[8.0]
  # Statements::ReapStalledJob scans for status = processing past a cutoff every
  # 15 minutes, and status had no index at all.
  def change
    add_index :statement_files, [ :status, :updated_at ]
  end
end
