class ChangeSupportedToSupportedTypeInBanks < ActiveRecord::Migration[8.0]
  def up
    # Add the new supported_type column as enum
    add_column :banks, :supported_type, :integer, default: nil, null: true

    # Start with all banks as unsupported (supported_type = NULL)
    # We'll configure specific banks later based on their actual parser capabilities
    # This gives us a clean slate to work with

    # Remove the old supported column
    remove_column :banks, :supported
  end

  def down
    # Add back the supported column
    add_column :banks, :supported, :boolean, default: true, null: false

    # Migrate data back
    execute <<-SQL
      UPDATE banks#{' '}
      SET supported = (supported_type IS NOT NULL);
    SQL

    # Remove the supported_type column
    remove_column :banks, :supported_type
  end
end
