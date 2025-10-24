class AddCutoffDateToStatementFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :statement_files, :cutoff_date, :datetime
    add_index :statement_files, :cutoff_date
  end
end
