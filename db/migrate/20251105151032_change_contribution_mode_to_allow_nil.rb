class ChangeContributionModeToAllowNil < ActiveRecord::Migration[8.0]
  def up
    # Update existing "none" values to NULL
    execute "UPDATE savings SET contribution_mode = NULL WHERE contribution_mode = 'none'"

    # Remove the default value from the column
    change_column_default :savings, :contribution_mode, from: "none", to: nil
  end

  def down
    # Restore the default value
    change_column_default :savings, :contribution_mode, from: nil, to: "none"

    # Update NULL values back to "none"
    execute "UPDATE savings SET contribution_mode = 'none' WHERE contribution_mode IS NULL"
  end
end
