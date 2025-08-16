class CategoryTemplate
  # This is a service class, not an ActiveRecord model

  class << self
    def create_categories_for_user(user)
      default_categories.each do |category_data|
        parent = user.categories.create!(
          name: category_data[:name],
          parent_id: nil
        )

        category_data[:subcategories]&.each do |sub_name|
          user.categories.create!(
            name: sub_name,
            parent: parent
          )
        end
      end
    end

    private

    def default_categories
      [
        {
          name: "Comida",
          subcategories: [ "Mandado", "Restaurantes", "Delivery", "Café", "Bares" ]
        },
        {
          name: "Transporte",
          subcategories: [ "Gasolina", "Uber/Didi", "Metro/Bus", "Estacionamiento", "Mantenimiento" ]
        },
        {
          name: "Compras",
          subcategories: [ "Ropa", "Electrónicos", "Hogar", "Libros", "Deportes" ]
        },
        {
          name: "Entretenimiento",
          subcategories: [ "Cine", "Streaming", "Juegos", "Conciertos", "Eventos" ]
        },
        {
          name: "Salud",
          subcategories: [ "Farmacia", "Doctores", "Gimnasio", "Seguro", "Dental" ]
        },
        {
          name: "Servicios",
          subcategories: [ "Luz", "Agua", "Internet", "Teléfono", "Gas" ]
        },
        {
          name: "Ingresos",
          subcategories: [ "Nómina", "Freelance", "Inversiones", "Bonos", "Otros" ]
        },
        {
          name: "Educación",
          subcategories: [ "Cursos", "Libros", "Software", "Certificaciones" ]
        },
        {
          name: "Viajes",
          subcategories: [ "Hoteles", "Vuelos", "Transporte", "Comidas", "Actividades" ]
        },
        {
          name: "Regalos",
          subcategories: [ "Cumpleaños", "Navidad", "Aniversario", "Otros" ]
        },
        {
          name: "Impuestos",
          subcategories: [ "ISR", "IVA", "Predial", "Tenencia", "Otros" ]
        },
        {
          name: "Ahorros",
          subcategories: [ "Cuenta de Ahorro", "Inversiones", "Fondo de Emergencia" ]
        }
      ]
    end
  end
end
