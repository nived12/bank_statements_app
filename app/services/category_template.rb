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
      name: "Viajes",
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

    user.categories.create!(
      name: "Fondo de Vacaciones",
      icon: "plane",
      parent: savings_category
    )

    # ========================================
    # VACATIONS
    # ========================================
    vacations_category = user.categories.create!(
      name: "Vacaciones",
      icon: "palmtree"
    )

    user.categories.create!(
      name: "Alojamiento",
      icon: "hotel",
      parent: vacations_category
    )

    user.categories.create!(
      name: "Vuelos",
      icon: "plane",
      parent: vacations_category
    )

    user.categories.create!(
      name: "Transporte Local",
      icon: "car",
      parent: vacations_category
    )

    user.categories.create!(
      name: "Comidas y Restaurantes",
      icon: "utensils",
      parent: vacations_category
    )

    user.categories.create!(
      name: "Actividades y Tours",
      icon: "ticket",
      parent: vacations_category
    )

    user.categories.create!(
      name: "Souvenirs",
      icon: "gift",
      parent: vacations_category
    )

    user.categories.create!(
      name: "Seguro de Viaje",
      icon: "shield",
      parent: vacations_category
    )

    # ========================================
    # DEBTS & LOANS
    # ========================================
    debts_category = user.categories.create!(
      name: "Deudas y Préstamos",
      icon: "credit-card"
    )

    user.categories.create!(
      name: "Tarjetas de Crédito",
      icon: "credit-card",
      parent: debts_category
    )

    user.categories.create!(
      name: "Préstamos Personales",
      icon: "banknote",
      parent: debts_category
    )

    user.categories.create!(
      name: "Préstamo Estudiantil",
      icon: "graduation-cap",
      parent: debts_category
    )

    user.categories.create!(
      name: "Crédito Automotriz",
      icon: "car",
      parent: debts_category
    )

    user.categories.create!(
      name: "Línea de Crédito",
      icon: "wallet",
      parent: debts_category
    )

    user.categories.create!(
      name: "Otras Deudas",
      icon: "circle-dot",
      parent: debts_category
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

    user.categories.create!(
      name: "Multas y Penalidades",
      icon: "alert-triangle",
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
    # INSURANCE
    # ========================================
    insurance_category = user.categories.create!(
      name: "Seguros",
      icon: "shield"
    )

    user.categories.create!(
      name: "Seguro de Vida",
      icon: "heart",
      parent: insurance_category
    )

    user.categories.create!(
      name: "Seguro de Salud",
      icon: "heart-pulse",
      parent: insurance_category
    )

    user.categories.create!(
      name: "Seguro del Hogar",
      icon: "home",
      parent: insurance_category
    )

    user.categories.create!(
      name: "Seguro de Auto",
      icon: "car",
      parent: insurance_category
    )

    user.categories.create!(
      name: "Otros Seguros",
      icon: "shield",
      parent: insurance_category
    )

    # ========================================
    # CHILDREN & FAMILY
    # ========================================
    family_category = user.categories.create!(
      name: "Familia e Hijos",
      icon: "users"
    )

    user.categories.create!(
      name: "Guardería y Cuidado Infantil",
      icon: "baby",
      parent: family_category
    )

    user.categories.create!(
      name: "Pañales y Suministros para Bebé",
      icon: "baby",
      parent: family_category
    )

    user.categories.create!(
      name: "Ropa para Niños",
      icon: "shirt",
      parent: family_category
    )

    user.categories.create!(
      name: "Juguetes",
      icon: "gamepad-2",
      parent: family_category
    )

    user.categories.create!(
      name: "Actividades Extracurriculares",
      icon: "award",
      parent: family_category
    )

    user.categories.create!(
      name: "Pensión Alimenticia",
      icon: "banknote",
      parent: family_category
    )

    # ========================================
    # CHARITY & DONATIONS
    # ========================================
    charity_category = user.categories.create!(
      name: "Caridad y Donaciones",
      icon: "heart-handshake"
    )

    user.categories.create!(
      name: "Donaciones",
      icon: "hand-heart",
      parent: charity_category
    )

    user.categories.create!(
      name: "Iglesia/Templo",
      icon: "church",
      parent: charity_category
    )

    user.categories.create!(
      name: "Organizaciones sin Fines de Lucro",
      icon: "users",
      parent: charity_category
    )

    # ========================================
    # BUSINESS EXPENSES
    # ========================================
    business_category = user.categories.create!(
      name: "Gastos de Negocio",
      icon: "briefcase"
    )

    user.categories.create!(
      name: "Oficina y Suministros",
      icon: "package",
      parent: business_category
    )

    user.categories.create!(
      name: "Marketing y Publicidad",
      icon: "megaphone",
      parent: business_category
    )

    user.categories.create!(
      name: "Viajes de Negocio",
      icon: "plane",
      parent: business_category
    )

    user.categories.create!(
      name: "Software y Herramientas",
      icon: "laptop",
      parent: business_category
    )

    user.categories.create!(
      name: "Servicios Profesionales",
      icon: "user-check",
      parent: business_category
    )

    user.categories.create!(
      name: "Comidas de Negocio",
      icon: "utensils",
      parent: business_category
    )

    # ========================================
    # LEGAL & PROFESSIONAL
    # ========================================
    legal_category = user.categories.create!(
      name: "Legal y Profesional",
      icon: "scale"
    )

    user.categories.create!(
      name: "Abogado",
      icon: "scale",
      parent: legal_category
    )

    user.categories.create!(
      name: "Contador",
      icon: "calculator",
      parent: legal_category
    )

    user.categories.create!(
      name: "Asesor Financiero",
      icon: "chart-bar",
      parent: legal_category
    )

    user.categories.create!(
      name: "Notario",
      icon: "file-text",
      parent: legal_category
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
