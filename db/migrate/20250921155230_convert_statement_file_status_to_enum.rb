class ConvertStatementFileStatusToEnum < ActiveRecord::Migration[8.0]
  def up
    # Add the enum column with a default value
    add_column :statement_files, :status_enum, :integer, default: 0, null: false

    # Map string values to enum values
    # 0 = pending, 1 = processing, 2 = parsed, 3 = error
    execute <<-SQL
      UPDATE statement_files#{' '}
      SET status_enum = CASE#{' '}
        WHEN status = 'pending' THEN 0
        WHEN status = 'processing' THEN 1
        WHEN status = 'parsed' THEN 2
        WHEN status = 'error' THEN 3
        ELSE 0
      END
    SQL

    # Remove the old string column
    remove_column :statement_files, :status

    # Rename the new column to status
    rename_column :statement_files, :status_enum, :status
  end

  def down
    # Add back the string column
    add_column :statement_files, :status_string, :string

    # Map enum values back to string values
    execute <<-SQL
      UPDATE statement_files#{' '}
      SET status_string = CASE#{' '}
        WHEN status = 0 THEN 'pending'
        WHEN status = 1 THEN 'processing'
        WHEN status = 2 THEN 'parsed'
        WHEN status = 3 THEN 'error'
        ELSE 'pending'
      END
    SQL

    # Remove the enum column
    remove_column :statement_files, :status

    # Rename the string column back to status
    rename_column :statement_files, :status_string, :status
  end
end
