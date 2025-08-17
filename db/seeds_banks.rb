# db/seeds_banks.rb
# Seed file for supported banks

puts "Creating supported banks..."

# BBVA
Bank.find_or_create_by(code: 'bbva') do |bank|
  bank.name = 'BBVA'
  bank.display_name = 'BBVA Bancomer'
  bank.supported = true
  bank.active = true
end

# Santander
Bank.find_or_create_by(code: 'santander') do |bank|
  bank.name = 'Santander'
  bank.display_name = 'Banco Santander'
  bank.supported = true
  bank.active = true
end

# Banorte
Bank.find_or_create_by(code: 'banorte') do |bank|
  bank.name = 'Banorte'
  bank.display_name = 'Banco Banorte'
  bank.supported = true
  bank.active = true
end

# Banamex
Bank.find_or_create_by(code: 'banamex') do |bank|
  bank.name = 'Banamex'
  bank.display_name = 'Banco Banamex'
  bank.supported = true
  bank.active = true
end

# Generic (for unsupported banks)
Bank.find_or_create_by(code: 'generic') do |bank|
  bank.name = 'Generic'
  bank.display_name = 'Other Bank'
  bank.supported = false
  bank.active = true
end

puts "Supported banks created successfully!"
puts "Total banks: #{Bank.count}"
puts "Supported banks: #{Bank.supported.count}"
