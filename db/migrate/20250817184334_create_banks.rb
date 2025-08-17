class CreateBanks < ActiveRecord::Migration[7.1]
  def change
    # Step 1: Create the banks table
    create_table :banks do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :name, null: false
      t.boolean :supported, default: true, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    # Step 2: Add bank_id to bank_accounts as nullable first
    add_reference :bank_accounts, :bank, null: true, foreign_key: true, index: true

    # Step 3: Add custom_name column
    add_column :bank_accounts, :custom_name, :string, limit: 100

    # Step 4: Create the basic banks
    reversible do |dir|
      dir.up do
        # Create major Mexican banks
        execute <<-SQL
          INSERT INTO banks (code, name, supported, active, created_at, updated_at) VALUES
          ('bbva', 'BBVA Bancomer', true, true, NOW(), NOW()),
          ('banamex', 'Banamex', true, true, NOW(), NOW()),
          ('banorte', 'Banorte', true, true, NOW(), NOW()),
          ('santander', 'Santander', true, true, NOW(), NOW()),
          ('hsbc', 'HSBC México', true, true, NOW(), NOW()),
          ('azteca', 'Banco Azteca', true, true, NOW(), NOW()),
          ('bajio', 'Banco del Bajío', true, true, NOW(), NOW()),
          ('banregio', 'Banregio', true, true, NOW(), NOW()),
          ('inbursa', 'Inbursa', true, true, NOW(), NOW()),
          ('scotiabank', 'Scotiabank México', true, true, NOW(), NOW()),
          ('generic', 'Otro Banco', false, true, NOW(), NOW())
        SQL

        # Migrate existing bank accounts to assign them to appropriate banks
        execute <<-SQL
          UPDATE bank_accounts#{' '}
          SET bank_id = (
            CASE#{' '}
              WHEN LOWER(bank_name) LIKE '%bbva%' THEN (SELECT id FROM banks WHERE code = 'bbva')
              WHEN LOWER(bank_name) LIKE '%banamex%' THEN (SELECT id FROM banks WHERE code = 'banamex')
              WHEN LOWER(bank_name) LIKE '%banorte%' THEN (SELECT id FROM banks WHERE code = 'banorte')
              WHEN LOWER(bank_name) LIKE '%santander%' THEN (SELECT id FROM banks WHERE code = 'santander')
              WHEN LOWER(bank_name) LIKE '%hsbc%' THEN (SELECT id FROM banks WHERE code = 'hsbc')
              WHEN LOWER(bank_name) LIKE '%azteca%' THEN (SELECT id FROM banks WHERE code = 'azteca')
              WHEN LOWER(bank_name) LIKE '%bajio%' OR LOWER(bank_name) LIKE '%bajío%' THEN (SELECT id FROM banks WHERE code = 'bajio')
              WHEN LOWER(bank_name) LIKE '%banregio%' THEN (SELECT id FROM banks WHERE code = 'banregio')
              WHEN LOWER(bank_name) LIKE '%inbursa%' THEN (SELECT id FROM banks WHERE code = 'inbursa')
              WHEN LOWER(bank_name) LIKE '%scotiabank%' THEN (SELECT id FROM banks WHERE code = 'scotiabank')
              ELSE (SELECT id FROM banks WHERE code = 'generic')
            END
          )
          WHERE bank_id IS NULL
        SQL

        # Set custom_name to the old bank_name for existing accounts
        execute <<-SQL
          UPDATE bank_accounts#{' '}
          SET custom_name = bank_name#{' '}
          WHERE custom_name IS NULL AND bank_name IS NOT NULL
        SQL
      end

      dir.down do
        # Remove the banks
        execute "DELETE FROM banks"
      end
    end

    # Step 5: Now make bank_id non-nullable
    change_column_null :bank_accounts, :bank_id, false

    # Step 6: Remove the old bank_name column
    remove_column :bank_accounts, :bank_name, :string
  end
end
