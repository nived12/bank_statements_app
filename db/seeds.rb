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

# Create categories for the user
food = Category.find_or_create_by!(user: user, name: "Comida")
Category.find_or_create_by!(user: user, parent: food, name: "Mandado")
Category.find_or_create_by!(user: user, parent: food, name: "Restaurantes")
Category.find_or_create_by!(user: user, parent: food, name: "Delivery")
Category.find_or_create_by!(user: user, parent: food, name: "Café")
Category.find_or_create_by!(user: user, parent: food, name: "Bares")

transport = Category.find_or_create_by!(user: user, name: "Transporte")
Category.find_or_create_by!(user: user, parent: transport, name: "Gasolina")
Category.find_or_create_by!(user: user, parent: transport, name: "Uber/Didi")
Category.find_or_create_by!(user: user, parent: transport, name: "Metro/Bus")
Category.find_or_create_by!(user: user, parent: transport, name: "Estacionamiento")
Category.find_or_create_by!(user: user, parent: transport, name: "Mantenimiento")

shopping = Category.find_or_create_by!(user: user, name: "Compras")
Category.find_or_create_by!(user: user, parent: shopping, name: "Ropa")
Category.find_or_create_by!(user: user, parent: shopping, name: "Electrónicos")
Category.find_or_create_by!(user: user, parent: shopping, name: "Hogar")
Category.find_or_create_by!(user: user, parent: shopping, name: "Libros")
Category.find_or_create_by!(user: user, parent: shopping, name: "Deportes")

entertainment = Category.find_or_create_by!(user: user, name: "Entretenimiento")
Category.find_or_create_by!(user: user, parent: entertainment, name: "Cine")
Category.find_or_create_by!(user: user, parent: entertainment, name: "Conciertos")
Category.find_or_create_by!(user: user, parent: entertainment, name: "Museos")
Category.find_or_create_by!(user: user, parent: entertainment, name: "Streaming")
Category.find_or_create_by!(user: user, parent: entertainment, name: "Juegos")

health = Category.find_or_create_by!(user: user, name: "Salud")
Category.find_or_create_by!(user: user, parent: health, name: "Farmacia")
Category.find_or_create_by!(user: user, parent: health, name: "Doctores")
Category.find_or_create_by!(user: user, parent: health, name: "Gimnasio")
Category.find_or_create_by!(user: user, parent: health, name: "Seguro médico")

utilities = Category.find_or_create_by!(user: user, name: "Servicios")
Category.find_or_create_by!(user: user, parent: utilities, name: "Luz")
Category.find_or_create_by!(user: user, parent: utilities, name: "Agua")
Category.find_or_create_by!(user: user, parent: utilities, name: "Internet")
Category.find_or_create_by!(user: user, parent: utilities, name: "Teléfono")
Category.find_or_create_by!(user: user, parent: utilities, name: "Gas")

income = Category.find_or_create_by!(user: user, name: "Ingresos")
Category.find_or_create_by!(user: user, parent: income, name: "Nómina")
Category.find_or_create_by!(user: user, parent: income, name: "Freelance")
Category.find_or_create_by!(user: user, parent: income, name: "Inversiones")
Category.find_or_create_by!(user: user, parent: income, name: "Reembolsos")
Category.find_or_create_by!(user: user, parent: income, name: "Transferencias")

banking = Category.find_or_create_by!(user: user, name: "Bancario")
Category.find_or_create_by!(user: user, parent: banking, name: "Comisiones")
Category.find_or_create_by!(user: user, parent: banking, name: "Intereses")
Category.find_or_create_by!(user: user, parent: banking, name: "SPEI")
Category.find_or_create_by!(user: user, parent: banking, name: "Retiros")
Category.find_or_create_by!(user: user, parent: banking, name: "Depósitos")

education = Category.find_or_create_by!(user: user, name: "Educación")
Category.find_or_create_by!(user: user, parent: education, name: "Cursos")
Category.find_or_create_by!(user: user, parent: education, name: "Libros")
Category.find_or_create_by!(user: user, parent: education, name: "Software")
Category.find_or_create_by!(user: user, parent: education, name: "Certificaciones")

travel = Category.find_or_create_by!(user: user, name: "Viajes")
Category.find_or_create_by!(user: user, parent: travel, name: "Hoteles")
Category.find_or_create_by!(user: user, parent: travel, name: "Vuelos")
Category.find_or_create_by!(user: user, parent: travel, name: "Renta de autos")
Category.find_or_create_by!(user: user, parent: travel, name: "Actividades")

charity = Category.find_or_create_by!(user: user, name: "Donaciones")
Category.find_or_create_by!(user: user, parent: charity, name: "ONGs")
Category.find_or_create_by!(user: user, parent: charity, name: "Iglesia")
Category.find_or_create_by!(user: user, parent: charity, name: "Crowdfunding")
