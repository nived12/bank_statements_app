class CategoryTemplate
  def self.create_categories_for_user(user)
    # Skip if user already has categories
    return if user.categories.exists?

    # ========================================
    # INCOME CATEGORIES
    # ========================================
    income_category = user.categories.create!(
      name: "Ingresos",
      icon: "banknote"
    )

    user.categories.create!(
      name: "Salario",
      icon: "briefcase",
      parent: income_category
    )

    user.categories.create!(
      name: "Freelance",
      icon: "laptop",
      parent: income_category
    )

    user.categories.create!(
      name: "Inversiones",
      icon: "chart-bar",
      parent: income_category
    )

    user.categories.create!(
      name: "Bonos y Propinas",
      icon: "coins",
      parent: income_category
    )

    user.categories.create!(
      name: "Otros Ingresos",
      icon: "circle-dot",
      parent: income_category
    )

    # ========================================
    # HOUSING & UTILITIES
    # ========================================
    housing_category = user.categories.create!(
      name: "Vivienda",
      icon: "home"
    )

    user.categories.create!(
      name: "Alquiler",
      icon: "key",
      parent: housing_category
    )

    user.categories.create!(
      name: "Hipoteca",
      icon: "landmark",
      parent: housing_category
    )

    user.categories.create!(
      name: "Mantenimiento del Hogar",
      icon: "wrench",
      parent: housing_category
    )

    user.categories.create!(
      name: "Muebles y Decoración",
      icon: "sofa",
      parent: housing_category
    )

    user.categories.create!(
      name: "Seguro de Hogar",
      icon: "shield",
      parent: housing_category
    )

    # ========================================
    # UTILITIES & SERVICES
    # ========================================
    services_category = user.categories.create!(
      name: "Servicios",
      icon: "zap"
    )

    user.categories.create!(
      name: "Electricidad",
      icon: "zap",
      parent: services_category
    )

    user.categories.create!(
      name: "Agua",
      icon: "droplet",
      parent: services_category
    )

    user.categories.create!(
      name: "Gas",
      icon: "flame",
      parent: services_category
    )

    user.categories.create!(
      name: "Internet",
      icon: "wifi",
      parent: services_category
    )

    user.categories.create!(
      name: "Telefonía",
      icon: "smartphone",
      parent: services_category
    )

    # ========================================
    # FOOD & DINING
    # ========================================
    food_category = user.categories.create!(
      name: "Comida",
      icon: "utensils"
    )

    user.categories.create!(
      name: "Supermercado",
      icon: "shopping-cart",
      parent: food_category
    )

    user.categories.create!(
      name: "Restaurantes",
      icon: "restaurant",
      parent: food_category
    )

    user.categories.create!(
      name: "Delivery",
      icon: "truck",
      parent: food_category
    )

    user.categories.create!(
      name: "Café y Snacks",
      icon: "coffee",
      parent: food_category
    )

    user.categories.create!(
      name: "Bebidas Alcohólicas",
      icon: "wine",
      parent: food_category
    )

    # ========================================
    # TRANSPORTATION
    # ========================================
    transport_category = user.categories.create!(
      name: "Transporte",
      icon: "car"
    )

    user.categories.create!(
      name: "Gasolina",
      icon: "fuel",
      parent: transport_category
    )

    user.categories.create!(
      name: "Transporte Público",
      icon: "bus",
      parent: transport_category
    )

    user.categories.create!(
      name: "Taxi y Rideshare",
      icon: "taxi",
      parent: transport_category
    )

    user.categories.create!(
      name: "Mantenimiento de Vehículo",
      icon: "wrench",
      parent: transport_category
    )

    user.categories.create!(
      name: "Estacionamiento",
      icon: "square-parking",
      parent: transport_category
    )

    user.categories.create!(
      name: "Seguro de Vehículo",
      icon: "shield",
      parent: transport_category
    )

    # ========================================
    # SHOPPING
    # ========================================
    shopping_category = user.categories.create!(
      name: "Compras",
      icon: "shopping-bag"
    )

    user.categories.create!(
      name: "Ropa y Calzado",
      icon: "shirt",
      parent: shopping_category
    )

    user.categories.create!(
      name: "Tecnología",
      icon: "smartphone",
      parent: shopping_category
    )

    user.categories.create!(
      name: "Electrodomésticos",
      icon: "refrigerator",
      parent: shopping_category
    )

    user.categories.create!(
      name: "Accesorios",
      icon: "watch",
      parent: shopping_category
    )

    user.categories.create!(
      name: "Regalos",
      icon: "gift",
      parent: shopping_category
    )

    # ========================================
    # HEALTH & WELLNESS
    # ========================================
    health_category = user.categories.create!(
      name: "Salud",
      icon: "heart"
    )

    user.categories.create!(
      name: "Médico",
      icon: "hospital",
      parent: health_category
    )

    user.categories.create!(
      name: "Medicamentos",
      icon: "pill",
      parent: health_category
    )

    user.categories.create!(
      name: "Dentista",
      icon: "hospital",
      parent: health_category
    )

    user.categories.create!(
      name: "Seguro Médico",
      icon: "shield",
      parent: health_category
    )

    user.categories.create!(
      name: "Gimnasio y Fitness",
      icon: "dumbbell",
      parent: health_category
    )

    user.categories.create!(
      name: "Terapia y Bienestar",
      icon: "heart",
      parent: health_category
    )

    # ========================================
    # PERSONAL CARE
    # ========================================
    personal_care_category = user.categories.create!(
      name: "Cuidado Personal",
      icon: "sparkles"
    )

    user.categories.create!(
      name: "Peluquería y Salón",
      icon: "scissors",
      parent: personal_care_category
    )

    user.categories.create!(
      name: "Cosméticos",
      icon: "sparkles",
      parent: personal_care_category
    )

    user.categories.create!(
      name: "Spa y Masajes",
      icon: "heart",
      parent: personal_care_category
    )

    # ========================================
    # ENTERTAINMENT
    # ========================================
    entertainment_category = user.categories.create!(
      name: "Entretenimiento",
      icon: "film"
    )

    user.categories.create!(
      name: "Cine y Teatro",
      icon: "film",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Conciertos y Eventos",
      icon: "music",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Deportes y Actividades",
      icon: "dumbbell",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Viajes y Turismo",
      icon: "plane",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Hobbies",
      icon: "star",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Videojuegos",
      icon: "gamepad-2",
      parent: entertainment_category
    )

    user.categories.create!(
      name: "Libros y Revistas",
      icon: "book",
      parent: entertainment_category
    )

    # ========================================
    # SUBSCRIPTIONS
    # ========================================
    subscriptions_category = user.categories.create!(
      name: "Suscripciones",
      icon: "monitor"
    )

    user.categories.create!(
      name: "Streaming (Netflix, Spotify, etc)",
      icon: "tv",
      parent: subscriptions_category
    )

    user.categories.create!(
      name: "Software y Apps",
      icon: "smartphone",
      parent: subscriptions_category
    )

    user.categories.create!(
      name: "Membresías",
      icon: "star",
      parent: subscriptions_category
    )

    user.categories.create!(
      name: "Noticias y Publicaciones",
      icon: "book-open",
      parent: subscriptions_category
    )

    # ========================================
    # EDUCATION
    # ========================================
    education_category = user.categories.create!(
      name: "Educación",
      icon: "graduation-cap"
    )

    user.categories.create!(
      name: "Matrícula Escolar",
      icon: "graduation-cap",
      parent: education_category
    )

    user.categories.create!(
      name: "Cursos y Talleres",
      icon: "book-open",
      parent: education_category
    )

    user.categories.create!(
      name: "Libros y Material Escolar",
      icon: "pencil",
      parent: education_category
    )

    user.categories.create!(
      name: "Tutorías",
      icon: "book",
      parent: education_category
    )

    # ========================================
    # PETS
    # ========================================
    pets_category = user.categories.create!(
      name: "Mascotas",
      icon: "dog"
    )

    user.categories.create!(
      name: "Comida para Mascotas",
      icon: "dog",
      parent: pets_category
    )

    user.categories.create!(
      name: "Veterinario",
      icon: "hospital",
      parent: pets_category
    )

    user.categories.create!(
      name: "Accesorios y Suministros",
      icon: "package",
      parent: pets_category
    )

    user.categories.create!(
      name: "Seguro de Mascota",
      icon: "shield",
      parent: pets_category
    )

    # ========================================
    # SAVINGS & INVESTMENTS
    # ========================================
    savings_category = user.categories.create!(
      name: "Ahorros e Inversiones",
      icon: "piggy-bank"
    )

    user.categories.create!(
      name: "Cuenta de Ahorros",
      icon: "piggy-bank",
      parent: savings_category
    )

    user.categories.create!(
      name: "Inversiones",
      icon: "chart-bar",
      parent: savings_category
    )

    user.categories.create!(
      name: "Fondo de Emergencia",
      icon: "shield",
      parent: savings_category
    )

    user.categories.create!(
      name: "Retiro/Pensión",
      icon: "landmark",
      parent: savings_category
    )

    # ========================================
    # TAXES & FEES
    # ========================================
    taxes_category = user.categories.create!(
      name: "Impuestos y Comisiones",
      icon: "receipt"
    )

    user.categories.create!(
      name: "Impuestos",
      icon: "calculator",
      parent: taxes_category
    )

    user.categories.create!(
      name: "Comisiones Bancarias",
      icon: "credit-card",
      parent: taxes_category
    )

    user.categories.create!(
      name: "Cargos por Servicios",
      icon: "receipt",
      parent: taxes_category
    )

    # ========================================
    # TRANSFERS & PAYMENTS
    # ========================================
    transfers_category = user.categories.create!(
      name: "Transferencias",
      icon: "arrow-left-right"
    )

    user.categories.create!(
      name: "Transferencias Bancarias",
      icon: "arrow-left-right",
      parent: transfers_category
    )

    user.categories.create!(
      name: "Pagos de Deudas",
      icon: "credit-card",
      parent: transfers_category
    )

    user.categories.create!(
      name: "Préstamos a Terceros",
      icon: "banknote",
      parent: transfers_category
    )

    # ========================================
    # MISCELLANEOUS
    # ========================================
    user.categories.create!(
      name: "Otros Gastos",
      icon: "circle-dot"
    )
  end
end
