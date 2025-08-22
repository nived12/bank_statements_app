# Production seeds - only essential data for production environment
# This file should only contain data that is absolutely necessary for the app to function

puts "🌱 Starting production seeds..."

# Create essential banks if they don't exist
if Bank.count.zero?
  puts "🏦 Creating essential banks..."

  banks_data = [
    { code: 'bbva', name: 'BBVA Bancomer', supported: true, active: true },
    { code: 'banamex', name: 'Banamex', supported: false, active: true },
    { code: 'banorte', name: 'Banorte', supported: false, active: true },
    { code: 'santander', name: 'Santander', supported: false, active: true },
    { code: 'hsbc', name: 'HSBC México', supported: false, active: true },
    { code: 'azteca', name: 'Banco Azteca', supported: false, active: true },
    { code: 'bajio', name: 'Banco del Bajío', supported: false, active: true },
    { code: 'banregio', name: 'Banregio', supported: false, active: true },
    { code: 'inbursa', name: 'Inbursa', supported: false, active: true },
    { code: 'scotiabank', name: 'Scotiabank México', supported: false, active: true },
    { code: 'generic', name: 'Otro Banco', supported: false, active: true }
  ]

  banks_data.each do |bank_attrs|
    Bank.create!(bank_attrs)
    puts "  ✅ Created bank: #{bank_attrs[:name]}"
  end

  puts "✅ Successfully created #{Bank.count} banks"
else
  puts "✅ Banks already exist (#{Bank.count} found)"
end

# Add any other essential production data here
# Examples:
# - System users
# - Configuration settings
# - etc.

puts "🌱 Production seeds completed!"
