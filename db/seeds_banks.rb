# db/seeds_banks.rb
# Seed file for supported banks

puts "Creating supported banks..."

# BBVA
Bank.find_or_create_by(code: "bbva") do |bank|
  bank.name = "BBVA Bancomer"
  bank.supported_type = :both
  bank.active = true
end

# Santander
Bank.find_or_create_by(code: "santander") do |bank|
  bank.name = "Banco Santander"
  bank.supported_type = :both
  bank.active = true
end

# Banorte
Bank.find_or_create_by(code: "banorte") do |bank|
  bank.name = "Banco Banorte"
  bank.supported_type = :both
  bank.active = true
end

# Banamex
Bank.find_or_create_by(code: "banamex") do |bank|
  bank.name = "Banamex"
  bank.supported_type = :both
  bank.active = true
end

# HSBC Mexico
Bank.find_or_create_by(code: "hsbc") do |bank|
  bank.name = "HSBC México"
  bank.supported_type = :both
  bank.active = true
end

# Scotiabank Mexico
Bank.find_or_create_by(code: "scotiabank") do |bank|
  bank.name = "Scotiabank México"
  bank.supported_type = :both
  bank.active = true
end

# Inbursa
Bank.find_or_create_by(code: "inbursa") do |bank|
  bank.name = "Banco Inbursa"
  bank.supported_type = :both
  bank.active = true
end

# Banco Azteca
Bank.find_or_create_by(code: "azteca") do |bank|
  bank.name = "Banco Azteca"
  bank.supported_type = :debit
  bank.active = true
end

# BanBajío
Bank.find_or_create_by(code: "banbajio") do |bank|
  bank.name = "BanBajío"
  bank.supported_type = :both
  bank.active = true
end

# Nu Mexico
Bank.find_or_create_by(code: "nu") do |bank|
  bank.name = "Nu México"
  bank.supported_type = :credit
  bank.active = true
end

# Banregio / Hey Banco
Bank.find_or_create_by(code: "banregio") do |bank|
  bank.name = "Banregio"
  bank.supported_type = :both
  bank.active = true
end

# Afirme
Bank.find_or_create_by(code: "afirme") do |bank|
  bank.name = "Banco Afirme"
  bank.supported_type = :both
  bank.active = true
end

# Revolut
Bank.find_or_create_by(code: "revolut") do |bank|
  bank.name = "Revolut"
  bank.supported_type = :both
  bank.active = true
end

# Generic (for unsupported banks)
Bank.find_or_create_by(code: "generic") do |bank|
  bank.name = "Other Bank"
  bank.supported_type = nil
  bank.active = true
end

# Update logo URLs
{
  "bbva"       => "banks/bbva.svg",
  "santander"  => "banks/santander.svg",
  "banorte"    => "banks/banorte.svg",
  "banamex"    => "banks/banamex.svg",
  "hsbc"       => "banks/hsbc.svg",
  "scotiabank" => "banks/scotiabank.svg",
  "inbursa"    => "banks/inbursa.svg",
  "azteca"     => "banks/azteca.svg",
  "banbajio"   => "banks/banbajio.svg",
  "nu"         => "banks/nu.svg",
  "banregio"   => "banks/banregio.svg",
  "afirme"     => "banks/afirme.svg",
  "revolut"    => "banks/revolut.svg"
}.each do |code, logo_url|
  Bank.find_by(code: code)&.update!(logo_url: logo_url)
end

puts "Supported banks created successfully!"
puts "Total banks: #{Bank.count}"
puts "Supported banks: #{Bank.supported.count}"
