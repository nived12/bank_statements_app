user = User.find_or_create_by!(email: "you@example.com") do |u|
  u.first_name = "You"
  u.last_name  = "Owner"
  u.password = "secret123"
  u.password_confirmation = "secret123"
end

ba = user.bank_accounts.find_or_create_by!(bank_name: "BBVA", account_number: "1234") do |b|
  b.currency = "MXN"
  b.opening_balance = 0.0
end
puts "User: #{user.email}, Bank account id: #{ba.id}"

food = Category.find_or_create_by!(user: user, name: "Comida")
Category.find_or_create_by!(user: user, parent: food, name: "Mandado")
Category.find_or_create_by!(user: user, parent: food, name: "Restaurantes")
