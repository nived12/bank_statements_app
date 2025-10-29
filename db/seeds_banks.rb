# db/seeds_banks.rb
# Seed file for supported banks

puts "Creating supported banks..."

# BBVA
Bank.find_or_create_by(code: 'bbva') do |bank|
  bank.name = 'BBVA Bancomer'
  bank.supported_type = :both
  bank.active = true
end

# Santander
Bank.find_or_create_by(code: 'santander') do |bank|
  bank.name = 'Banco Santander'
  bank.supported_type = :both
  bank.active = true
end

# Banorte
Bank.find_or_create_by(code: 'banorte') do |bank|
  bank.name = 'Banco Banorte'
  bank.supported_type = :both
  bank.active = true
end

# Banamex
Bank.find_or_create_by(code: 'banamex') do |bank|
  bank.name = 'Banco Banamex'
  bank.supported_type = :both
  bank.active = true
end

# Generic (for unsupported banks)
Bank.find_or_create_by(code: 'generic') do |bank|
  bank.name = 'Other Bank'
  bank.supported_type = nil
  bank.active = true
end

puts "Supported banks created successfully!"
puts "Total banks: #{Bank.count}"
puts "Supported banks: #{Bank.supported.count}"
