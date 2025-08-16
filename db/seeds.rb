# Handle existing data gracefully
puts "Setting up sample data..."

# Find or create user
user = User.find_or_create_by!(email: "nivedvengilat@example.com") do |u|
  u.first_name = "Nived"
  u.last_name = "Vengilat"
  u.password = "rayado123"
  u.password_confirmation = "rayado123"
end

puts "Using user: #{user.email}"

# Clear existing data for this user in the correct order (respecting foreign keys)
puts "Clearing existing user data..."

# First, delete transactions (they reference categories and statement files)
if user.transactions.exists?
  puts "  - Deleting #{user.transactions.count} transactions..."
  user.transactions.delete_all
end

# Then delete statement files
if user.statement_files.exists?
  puts "  - Deleting #{user.statement_files.count} statement files..."
  user.statement_files.delete_all
end

# Then delete categories (they might be referenced by transactions)
if user.categories.exists?
  puts "  - Deleting #{user.categories.count} categories..."
  user.categories.delete_all
end

# Finally delete bank accounts
if user.bank_accounts.exists?
  puts "  - Deleting #{user.bank_accounts.count} bank accounts..."
  user.bank_accounts.delete_all
end

puts "Cleared existing user data"

# Create default categories for the user
puts "Creating default categories..."
CategoryTemplate.create_categories_for_user(user)
puts "Created #{user.categories.count} categories"

# Create bank accounts
bbva_account = user.bank_accounts.create!(
  bank_name: "BBVA",
  account_number: "****1234",
  currency: "MXN",
  opening_balance: 50000.00
)

banorte_account = user.bank_accounts.create!(
  bank_name: "Banorte",
  account_number: "****5678",
  currency: "MXN",
  opening_balance: 75000.00
)

santander_account = user.bank_accounts.create!(
  bank_name: "Santander",
  account_number: "****9012",
  currency: "MXN",
  opening_balance: 120000.00
)

puts "Created #{user.bank_accounts.count} bank accounts"

# Create a simple statement file for each account (we'll skip file validation for testing)
bbva_statement = StatementFile.new(
  user: user,
  bank_account: bbva_account,
  status: "processed",
  processed_at: 1.day.ago
)
bbva_statement.save!(validate: false)

# Create financial summary for BBVA
bbva_statement.create_financial_summary!(
  statement_type: "savings",
  statement_type_data: {
    "total_deposits" => 50000,
    "total_withdrawals" => 0,
    "interest_earned" => 250
  },
  initial_balance: 0,
  final_balance: 50000,
  statement_period_start: 1.month.ago.beginning_of_month,
  statement_period_end: 1.month.ago.end_of_month,
  days_in_period: 30
)

banorte_statement = StatementFile.new(
  user: user,
  bank_account: banorte_account,
  status: "processed",
  processed_at: 2.days.ago
)
banorte_statement.save!(validate: false)

# Create financial summary for Banorte
banorte_statement.create_financial_summary!(
  statement_type: "savings",
  statement_type_data: {
    "total_deposits" => 75000,
    "total_withdrawals" => 0,
    "interest_earned" => 375
  },
  initial_balance: 0,
  final_balance: 75000,
  statement_period_start: 2.months.ago.beginning_of_month,
  statement_period_end: 2.months.ago.end_of_month,
  days_in_period: 30
)

santander_statement = StatementFile.new(
  user: user,
  bank_account: santander_account,
  status: "processed",
  processed_at: 3.days.ago
)
santander_statement.save!(validate: false)

# Create financial summary for Santander
santander_statement.create_financial_summary!(
  statement_type: "savings",
  statement_type_data: {
    "total_deposits" => 120000,
    "total_withdrawals" => 0,
    "interest_earned" => 600
  },
  initial_balance: 0,
  final_balance: 120000,
  statement_period_start: 3.months.ago.beginning_of_month,
  statement_period_end: 3.months.ago.end_of_month,
  days_in_period: 30
)

puts "Created #{StatementFile.count} statement files (validation skipped for testing)"

# Create transactions for the current month
current_month = Date.current.beginning_of_month

# Get category references
income_category = user.categories.find_by(name: "Ingresos")
food_category = user.categories.find_by(name: "Comida")
transport_category = user.categories.find_by(name: "Transporte")
entertainment_category = user.categories.find_by(name: "Entretenimiento")
utilities_category = user.categories.find_by(name: "Servicios")
health_category = user.categories.find_by(name: "Salud")
shopping_category = user.categories.find_by(name: "Compras")

# Income transactions
user.transactions.create!(
  bank_account: bbva_account,
  statement_file: bbva_statement,
  date: current_month + 5.days,
  description: "Nómina BBVA",
  amount: 25000.00,
  transaction_type: "income",
  bank_entry_type: "credit",
  category: income_category&.children&.find_by(name: "Nómina") || income_category
)

user.transactions.create!(
  bank_account: banorte_account,
  statement_file: banorte_statement,
  date: current_month + 7.days,
  description: "Freelance Project",
  amount: 15000.00,
  transaction_type: "income",
  bank_entry_type: "credit",
  category: income_category&.children&.find_by(name: "Freelance") || income_category
)

# Expense transactions
user.transactions.create!(
  bank_account: bbva_account,
  statement_file: bbva_statement,
  date: current_month + 2.days,
  description: "Supermercado Walmart",
  amount: 1250.50,
  transaction_type: "variable_expense",
  bank_entry_type: "debit",
  category: food_category&.children&.find_by(name: "Mandado") || food_category
)

user.transactions.create!(
  bank_account: bbva_account,
  statement_file: bbva_statement,
  date: current_month + 3.days,
  description: "Restaurante El Pescador",
  amount: 450.00,
  transaction_type: "variable_expense",
  bank_entry_type: "debit",
  category: food_category&.children&.find_by(name: "Restaurantes") || food_category
)

user.transactions.create!(
  bank_account: bbva_account,
  statement_file: bbva_statement,
  date: current_month + 4.days,
  description: "Gasolina Pemex",
  amount: 800.00,
  transaction_type: "variable_expense",
  bank_entry_type: "debit",
  category: transport_category&.children&.find_by(name: "Gasolina") || transport_category
)

user.transactions.create!(
  bank_account: banorte_account,
  statement_file: banorte_statement,
  date: current_month + 6.days,
  description: "Uber - Centro Comercial",
  amount: 120.00,
  transaction_type: "variable_expense",
  bank_entry_type: "debit",
  category: transport_category&.children&.find_by(name: "Uber/Didi") || transport_category
)

user.transactions.create!(
  bank_account: banorte_account,
  statement_file: banorte_statement,
  date: current_month + 8.days,
  description: "Netflix Subscription",
  amount: 199.00,
  transaction_type: "fixed_expense",
  bank_entry_type: "debit",
  category: entertainment_category&.children&.find_by(name: "Streaming") || entertainment_category
)

user.transactions.create!(
  bank_account: santander_account,
  statement_file: santander_statement,
  date: current_month + 1.days,
  description: "CFE Luz",
  amount: 850.00,
  transaction_type: "fixed_expense",
  bank_entry_type: "debit",
  category: utilities_category&.children&.find_by(name: "Luz") || utilities_category
)

user.transactions.create!(
  bank_account: santander_account,
  statement_file: santander_statement,
  date: current_month + 9.days,
  description: "Farmacia San Pablo",
  amount: 320.00,
  transaction_type: "variable_expense",
  bank_entry_type: "debit",
  category: health_category&.children&.find_by(name: "Farmacia") || health_category
)

user.transactions.create!(
  bank_account: santander_account,
  statement_file: santander_statement,
  date: current_month + 10.days,
  description: "Zara - Ropa",
  amount: 1200.00,
  transaction_type: "variable_expense",
  bank_entry_type: "debit",
  category: shopping_category&.children&.find_by(name: "Ropa") || shopping_category
)

# Create transactions for previous months to show spending trends
(1..5).each do |month_offset|
  month_start = current_month - month_offset.months
  month_end = month_start.end_of_month

  # Random expenses for each month
  rand(8..15).times do
    user.transactions.create!(
      bank_account: [ bbva_account, banorte_account, santander_account ].sample,
      statement_file: [ bbva_statement, banorte_statement, santander_statement ].sample,
      date: month_start + rand(0..(month_end - month_start).to_i).days,
      description: [
        "Supermercado #{[ 'Walmart', 'Soriana', 'Chedraui' ].sample}",
        "Restaurante #{[ 'El Pescador', 'La Casa', 'Sushi Bar' ].sample}",
        "Gasolina #{[ 'Pemex', 'Shell', 'BP' ].sample}",
        "Uber - #{[ 'Centro', 'Aeropuerto', 'Casa' ].sample}",
        "Netflix Subscription",
        "CFE Luz",
        "Farmacia #{[ 'San Pablo', 'Guadalajara', 'Benavides' ].sample}",
        "#{[ 'Zara', 'H&M', 'Pull&Bear' ].sample} - Ropa"
      ].sample,
      amount: rand(100..2000),
      transaction_type: [ "fixed_expense", "variable_expense" ].sample,
      bank_entry_type: "debit",
      category: [ food_category&.children, transport_category&.children, shopping_category&.children, entertainment_category&.children, health_category&.children, utilities_category&.children ].flatten.sample
    )
  end
end

puts "Created #{Transaction.count} transactions"

puts "\n🎉 Sample data created successfully!"
puts "📊 Dashboard should now show:"
puts "   - Total balance: $#{user.bank_accounts.sum(&:opening_balance)}"
puts "   - #{user.bank_accounts.count} bank accounts"
puts "   - #{user.transactions.count} transactions"
puts "   - #{user.categories.count} categories"
puts "   - Spending trends for the last 6 months"
puts "\n🌐 Visit http://localhost:3000 to see your dashboard!"
puts "👤 Login with: nivedvengilat@example.com / rayado123"
