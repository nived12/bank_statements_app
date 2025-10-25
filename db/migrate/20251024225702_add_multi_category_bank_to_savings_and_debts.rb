class AddMultiCategoryBankToSavingsAndDebts < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add new auto_sync_transactions field to both tables
    add_column :savings, :auto_sync_transactions, :boolean, default: false, null: false
    add_column :debts, :auto_sync_transactions, :boolean, default: false, null: false

    # Step 2: Create junction tables for many-to-many relationships
    create_table :saving_categories do |t|
      t.references :saving, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :saving_categories, [:saving_id, :category_id], unique: true

    create_table :saving_bank_accounts do |t|
      t.references :saving, null: false, foreign_key: true
      t.references :bank_account, null: false, foreign_key: true
      t.timestamps
    end
    add_index :saving_bank_accounts, [:saving_id, :bank_account_id], unique: true

    create_table :debt_categories do |t|
      t.references :debt, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :debt_categories, [:debt_id, :category_id], unique: true

    create_table :debt_bank_accounts do |t|
      t.references :debt, null: false, foreign_key: true
      t.references :bank_account, null: false, foreign_key: true
      t.timestamps
    end
    add_index :debt_bank_accounts, [:debt_id, :bank_account_id], unique: true

    # Step 3: Migrate existing data from old fields to new structure
    # For Savings
    execute <<-SQL
      UPDATE savings
      SET auto_sync_transactions = auto_link_category
      WHERE auto_link_category = true
    SQL

    # Create junction records for existing savings with category_id
    execute <<-SQL
      INSERT INTO saving_categories (saving_id, category_id, created_at, updated_at)
      SELECT id, category_id, NOW(), NOW()
      FROM savings
      WHERE category_id IS NOT NULL
    SQL

    # Create junction records for existing savings with bank_account_id
    execute <<-SQL
      INSERT INTO saving_bank_accounts (saving_id, bank_account_id, created_at, updated_at)
      SELECT id, bank_account_id, NOW(), NOW()
      FROM savings
      WHERE bank_account_id IS NOT NULL
    SQL

    # For Debts
    execute <<-SQL
      UPDATE debts
      SET auto_sync_transactions = auto_link_category
      WHERE auto_link_category = true
    SQL

    # Create junction records for existing debts with category_id
    execute <<-SQL
      INSERT INTO debt_categories (debt_id, category_id, created_at, updated_at)
      SELECT id, category_id, NOW(), NOW()
      FROM debts
      WHERE category_id IS NOT NULL
    SQL

    # Create junction records for existing debts with bank_account_id
    execute <<-SQL
      INSERT INTO debt_bank_accounts (debt_id, bank_account_id, created_at, updated_at)
      SELECT id, bank_account_id, NOW(), NOW()
      FROM debts
      WHERE bank_account_id IS NOT NULL
    SQL

    # Step 4: Remove old columns
    remove_column :savings, :auto_link_category
    remove_column :savings, :category_id
    remove_column :savings, :bank_account_id

    remove_column :debts, :auto_link_category
    remove_column :debts, :category_id
    remove_column :debts, :bank_account_id
  end

  def down
    # Step 1: Re-add old columns
    add_column :savings, :auto_link_category, :boolean, default: false, null: false
    add_column :savings, :category_id, :bigint
    add_column :savings, :bank_account_id, :bigint
    add_index :savings, :category_id
    add_index :savings, :bank_account_id

    add_column :debts, :auto_link_category, :boolean, default: false, null: false
    add_column :debts, :category_id, :bigint
    add_column :debts, :bank_account_id, :bigint
    add_index :debts, :category_id
    add_index :debts, :bank_account_id

    # Step 2: Migrate data back from new structure to old fields
    # For Savings - copy auto_sync_transactions back to auto_link_category
    execute <<-SQL
      UPDATE savings
      SET auto_link_category = auto_sync_transactions
      WHERE auto_sync_transactions = true
    SQL

    # For Savings - take the first category and bank_account from junction tables
    execute <<-SQL
      UPDATE savings
      SET category_id = (
        SELECT category_id FROM saving_categories
        WHERE saving_categories.saving_id = savings.id
        ORDER BY saving_categories.id
        LIMIT 1
      )
    SQL

    execute <<-SQL
      UPDATE savings
      SET bank_account_id = (
        SELECT bank_account_id FROM saving_bank_accounts
        WHERE saving_bank_accounts.saving_id = savings.id
        ORDER BY saving_bank_accounts.id
        LIMIT 1
      )
    SQL

    # For Debts
    execute <<-SQL
      UPDATE debts
      SET auto_link_category = auto_sync_transactions
      WHERE auto_sync_transactions = true
    SQL

    execute <<-SQL
      UPDATE debts
      SET category_id = (
        SELECT category_id FROM debt_categories
        WHERE debt_categories.debt_id = debts.id
        ORDER BY debt_categories.id
        LIMIT 1
      )
    SQL

    execute <<-SQL
      UPDATE debts
      SET bank_account_id = (
        SELECT bank_account_id FROM debt_bank_accounts
        WHERE debt_bank_accounts.debt_id = debts.id
        ORDER BY debt_bank_accounts.id
        LIMIT 1
      )
    SQL

    # Step 3: Drop junction tables
    drop_table :saving_categories
    drop_table :saving_bank_accounts
    drop_table :debt_categories
    drop_table :debt_bank_accounts

    # Step 4: Remove new column
    remove_column :savings, :auto_sync_transactions
    remove_column :debts, :auto_sync_transactions
  end
end
