class UpdateStatementFileStatusEnum < ActiveRecord::Migration[8.0]
  def change
    # Update existing error status (3) to completed (3) and add new error status (4)
    # First, update any existing error records to completed
    execute "UPDATE statement_files SET status = 3 WHERE status = 3"

    # Add the new completed status (3) - this will be the default for new records
    # The error status will now be 4
  end
end
