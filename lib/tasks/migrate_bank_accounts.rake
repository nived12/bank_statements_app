# lib/tasks/migrate_bank_accounts.rake
# Task to migrate existing bank accounts to the new Bank model structure

namespace :bank_accounts do
  desc "Migrate existing bank accounts to new Bank model structure"
  task migrate: :environment do
    puts "Starting bank account migration..."

    # First, ensure we have the basic banks
    puts "Creating basic banks..."

    bbva = Bank.find_or_create_by(code: "bbva") do |bank|
      bank.name = "BBVA Bancomer"
      bank.supported = true
      bank.active = true
    end

    banamex = Bank.find_or_create_by(code: "banamex") do |bank|
      bank.name = "Banamex"
      bank.supported = true
      bank.active = true
    end

    banorte = Bank.find_or_create_by(code: "banorte") do |bank|
      bank.name = "Banorte"
      bank.supported = true
      bank.active = true
    end

    santander = Bank.find_or_create_by(code: "santander") do |bank|
      bank.name = "Santander"
      bank.supported = true
      bank.active = true
    end

    hsbc = Bank.find_or_create_by(code: "hsbc") do |bank|
      bank.name = "HSBC México"
      bank.supported = true
      bank.active = true
    end

    azteca = Bank.find_or_create_by(code: "azteca") do |bank|
      bank.name = "Banco Azteca"
      bank.supported = true
      bank.active = true
    end

    bajio = Bank.find_or_create_by(code: "bajio") do |bank|
      bank.name = "Banco del Bajío"
      bank.supported = true
      bank.active = true
    end

    banregio = Bank.find_or_create_by(code: "banregio") do |bank|
      bank.name = "Banregio"
      bank.supported = true
      bank.active = true
    end

    inbursa = Bank.find_or_create_by(code: "inbursa") do |bank|
      bank.name = "Inbursa"
      bank.supported = true
      bank.active = true
    end

    scotiabank = Bank.find_or_create_by(code: "scotiabank") do |bank|
      bank.name = "Scotiabank México"
      bank.supported = true
      bank.active = true
    end

    generic = Bank.find_or_create_by(code: "generic") do |bank|
      bank.name = "Otro Banco"
      bank.supported = false
      bank.active = true
    end

    puts "Basic banks created/verified"

    # Now migrate existing bank accounts
    puts "Migrating existing bank accounts..."

    # Get all bank accounts that don't have a bank_id yet
    old_bank_accounts = BankAccount.where(bank_id: nil)

    if old_bank_accounts.any?
      puts "Found #{old_bank_accounts.count} bank accounts to migrate"

      old_bank_accounts.each do |account|
        puts "Migrating account: #{account.id} - #{account.read_attribute(:bank_name)}"

        # Try to find a matching bank
        bank_name = account.read_attribute(:bank_name)&.downcase&.strip

        if bank_name.blank?
          puts "  -> No bank name, assigning to generic"
          account.update!(bank: generic)
        elsif bank_name.include?("bbva")
          puts "  -> BBVA detected, assigning to BBVA"
          account.update!(bank: bbva)
        elsif bank_name.include?("banamex")
          puts "  -> Banamex detected, assigning to Banamex"
          account.update!(bank: banamex)
        elsif bank_name.include?("banorte")
          puts "  -> Banorte detected, assigning to Banorte"
          account.update!(bank: banorte)
        elsif bank_name.include?("santander")
          puts "  -> Santander detected, assigning to Santander"
          account.update!(bank: santander)
        elsif bank_name.include?("hsbc")
          puts "  -> HSBC detected, assigning to HSBC"
          account.update!(bank: hsbc)
        elsif bank_name.include?("azteca")
          puts "  -> Azteca detected, assigning to Azteca"
          account.update!(bank: azteca)
        elsif bank_name.include?("bajio") || bank_name.include?("bajío")
          puts "  -> Bajío detected, assigning to Bajío"
          account.update!(bank: bajio)
        elsif bank_name.include?("banregio")
          puts "  -> Banregio detected, assigning to Banregio"
          account.update!(bank: banregio)
        elsif bank_name.include?("inbursa")
          puts "  -> Inbursa detected, assigning to Inbursa"
          account.update!(bank: inbursa)
        elsif bank_name.include?("scotiabank")
          puts "  -> Scotiabank detected, assigning to Scotiabank"
          account.update!(bank: scotiabank)
        else
          puts "  -> Unknown bank '#{bank_name}', assigning to generic"
          account.update!(bank: generic)
        end
      end

      puts "Migration completed successfully!"
    else
      puts "No bank accounts to migrate"
    end

    # Show final stats
    puts "\nFinal statistics:"
    puts "Total banks: #{Bank.count}"
    puts "Total bank accounts: #{BankAccount.count}"
    puts "Bank accounts by bank:"
    Bank.all.each do |bank|
      count = bank.bank_accounts.count
      puts "  #{bank.name}: #{count} accounts"
    end
  end

  desc "Rollback bank account migration (for testing)"
  task rollback: :environment do
    puts "Rolling back bank account migration..."

    # Remove bank_id from all accounts
    BankAccount.update_all(bank_id: nil)

    # Remove custom_name column if it exists
    if BankAccount.column_names.include?("custom_name")
      BankAccount.update_all(custom_name: nil)
    end

    puts "Rollback completed"
  end
end
