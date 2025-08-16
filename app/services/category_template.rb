class CategoryTemplate
  def self.create_categories_for_user(user)
    # Create parent categories first
    food_category = user.categories.create!(
      name: "Comida"
    )

    transport_category = user.categories.create!(
      name: "Transporte"
    )

    entertainment_category = user.categories.create!(
      name: "Entretenimiento"
    )

    shopping_category = user.categories.create!(
      name: "Compras"
    )

    health_category = user.categories.create!(
      name: "Salud"
    )

    education_category = user.categories.create!(
      name: "Educación"
    )

    utilities_category = user.categories.create!(
      name: "Servicios"
    )

    income_category = user.categories.create!(
      name: "Ingresos"
    )

    # Create child categories
    # Comida subcategories
    user.categories.create!(
      name: "Restaurantes",
      parent: food_category
    )

    user.categories.create!(
      name: "Supermercado",
      parent: food_category
    )

    user.categories.create!(
      name: "Delivery",
      parent: food_category
    )

    user.categories.create!(
      name: "Bebidas",
      parent: food_category
    )

    # Transporte subcategories
    user.categories.create!(
      name: "Gasolina",
      parent: transport_category
    )

    user.categories.create!(
      name: "Transporte Público",
      parent: transport_category
    )

    user.categories.create!(
      name: "Mantenimiento",
      parent: transport_category
    )

    user.categories.create!(
      name: "Estacionamiento",
      parent: transport_category
    )

    # Entretenimiento subcategories
    user.categories.create!(
      name: "Cine",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Deportes",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Viajes",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Hobbies",
      parent: entertainment_category
    )

    # Compras subcategories
    user.categories.create!(
      name: "Ropa",
      parent: shopping_category
    )

    user.categories.create!(
      name: "Tecnología",
      parent: shopping_category
    )

    user.categories.create!(
      name: "Hogar",
      parent: shopping_category
    )

    user.categories.create!(
      name: "Cosméticos",
      parent: shopping_category
    )

    # Salud subcategories
    user.categories.create!(
      name: "Médico",
      parent: health_category
    )

    user.categories.create!(
      name: "Medicamentos",
      parent: health_category
    )

    user.categories.create!(
      name: "Seguro Médico",
      parent: health_category
    )

    # Educación subcategories
    user.categories.create!(
      name: "Cursos",
      parent: education_category
    )

    user.categories.create!(
      name: "Libros",
      parent: education_category
    )

    user.categories.create!(
      name: "Colegiatura",
      parent: education_category
    )

    # Servicios subcategories
    user.categories.create!(
      name: "Luz",
      parent: utilities_category
    )

    user.categories.create!(
      name: "Agua",
      parent: utilities_category
    )

    user.categories.create!(
      name: "Internet",
      parent: utilities_category
    )

    user.categories.create!(
      name: "Renta",
      parent: utilities_category
    )

    # Ingresos subcategories
    user.categories.create!(
      name: "Salario",
      parent: income_category
    )

    user.categories.create!(
      name: "Freelance",
      parent: income_category
    )

    user.categories.create!(
      name: "Inversiones",
      parent: income_category
    )

    user.categories.create!(
      name: "Otros Ingresos",
      parent: income_category
    )

    # Create Uncategorized category for transactions without specific category
    user.categories.create!(
      name: "Sin Categorizar"
    )
  end
end
