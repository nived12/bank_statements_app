class CategoryTemplate
  def self.create_categories_for_user(user)
    # Note: Categories are foundational taxonomy data, not example data
    # They should be created in all environments including test

    # ========================================
    # INCOME CATEGORIES
    # ========================================
    income_category = user.categories.find_or_create_by(
      name: "Ingresos",
      icon: "banknote"
    )

    user.categories.find_or_create_by(
      name: "Salario",
      icon: "briefcase",
      parent: income_category
    )

    user.categories.find_or_create_by(
      name: "Freelance",
      icon: "laptop",
      parent: income_category
    )

    user.categories.find_or_create_by(
      name: "Inversiones",
      icon: "chart-bar",
      parent: income_category
    )

    user.categories.find_or_create_by(
      name: "Bonos y Propinas",
      icon: "coins",
      parent: income_category
    )

    user.categories.find_or_create_by(
      name: "Otros Ingresos",
      icon: "circle-dot",
      parent: income_category
    )

    # ========================================
    # HOUSING & UTILITIES
    # ========================================
    housing_category = user.categories.find_or_create_by(
      name: "Vivienda",
      icon: "home"
    )

    user.categories.find_or_create_by(
      name: "Alquiler",
      icon: "key",
      parent: housing_category
    )

    user.categories.find_or_create_by(
      name: "Hipoteca",
      icon: "landmark",
      parent: housing_category
    )

    user.categories.find_or_create_by(
      name: "Mantenimiento del Hogar",
      icon: "wrench",
      parent: housing_category
    )

    user.categories.find_or_create_by(
      name: "Muebles y Decoración",
      icon: "sofa",
      parent: housing_category
    )

    user.categories.find_or_create_by(
      name: "Seguro de Hogar",
      icon: "shield",
      parent: housing_category
    )

    # ========================================
    # UTILITIES & SERVICES
    # ========================================
    services_category = user.categories.find_or_create_by(
      name: "Servicios",
      icon: "zap"
    )

    user.categories.find_or_create_by(
      name: "Electricidad",
      icon: "zap",
      parent: services_category
    )

    user.categories.find_or_create_by(
      name: "Agua",
      icon: "droplet",
      parent: services_category
    )

    user.categories.find_or_create_by(
      name: "Gas",
      icon: "flame",
      parent: services_category
    )

    user.categories.find_or_create_by(
      name: "Internet",
      icon: "wifi",
      parent: services_category
    )

    user.categories.find_or_create_by(
      name: "Telefonía",
      icon: "smartphone",
      parent: services_category
    )

    # ========================================
    # FOOD & DINING
    # ========================================
    food_category = user.categories.find_or_create_by(
      name: "Comida",
      icon: "utensils"
    )

    user.categories.find_or_create_by(
      name: "Supermercado",
      icon: "shopping-cart",
      parent: food_category
    )

    user.categories.find_or_create_by(
      name: "Restaurantes",
      icon: "restaurant",
      parent: food_category
    )

    user.categories.find_or_create_by(
      name: "Delivery",
      icon: "truck",
      parent: food_category
    )

    user.categories.find_or_create_by(
      name: "Café y Snacks",
      icon: "coffee",
      parent: food_category
    )

    user.categories.find_or_create_by(
      name: "Bebidas Alcohólicas",
      icon: "wine",
      parent: food_category
    )

    # ========================================
    # TRANSPORTATION
    # ========================================
    transport_category = user.categories.find_or_create_by(
      name: "Transporte",
      icon: "car"
    )

    user.categories.find_or_create_by(
      name: "Gasolina",
      icon: "fuel",
      parent: transport_category
    )

    user.categories.find_or_create_by(
      name: "Transporte Público",
      icon: "bus",
      parent: transport_category
    )

    user.categories.find_or_create_by(
      name: "Taxi y Rideshare",
      icon: "taxi",
      parent: transport_category
    )

    user.categories.find_or_create_by(
      name: "Mantenimiento de Vehículo",
      icon: "wrench",
      parent: transport_category
    )

    user.categories.find_or_create_by(
      name: "Estacionamiento",
      icon: "square-parking",
      parent: transport_category
    )

    user.categories.find_or_create_by(
      name: "Seguro de Vehículo",
      icon: "shield",
      parent: transport_category
    )

    # ========================================
    # SHOPPING
    # ========================================
    shopping_category = user.categories.find_or_create_by(
      name: "Compras",
      icon: "shopping-bag"
    )

    user.categories.find_or_create_by(
      name: "Ropa y Calzado",
      icon: "shirt",
      parent: shopping_category
    )

    user.categories.find_or_create_by(
      name: "Tecnología",
      icon: "smartphone",
      parent: shopping_category
    )

    user.categories.find_or_create_by(
      name: "Electrodomésticos",
      icon: "refrigerator",
      parent: shopping_category
    )

    user.categories.find_or_create_by(
      name: "Accesorios",
      icon: "watch",
      parent: shopping_category
    )

    user.categories.find_or_create_by(
      name: "Regalos",
      icon: "gift",
      parent: shopping_category
    )

    # ========================================
    # HEALTH & WELLNESS
    # ========================================
    health_category = user.categories.find_or_create_by(
      name: "Salud",
      icon: "heart"
    )

    user.categories.find_or_create_by(
      name: "Médico",
      icon: "hospital",
      parent: health_category
    )

    user.categories.find_or_create_by(
      name: "Medicamentos",
      icon: "pill",
      parent: health_category
    )

    user.categories.find_or_create_by(
      name: "Dentista",
      icon: "hospital",
      parent: health_category
    )

    user.categories.find_or_create_by(
      name: "Seguro Médico",
      icon: "shield",
      parent: health_category
    )

    user.categories.find_or_create_by(
      name: "Gimnasio y Fitness",
      icon: "dumbbell",
      parent: health_category
    )

    user.categories.find_or_create_by(
      name: "Terapia y Bienestar",
      icon: "heart",
      parent: health_category
    )

    # ========================================
    # PERSONAL CARE
    # ========================================
    personal_care_category = user.categories.find_or_create_by(
      name: "Cuidado Personal",
      icon: "sparkles"
    )

    user.categories.find_or_create_by(
      name: "Peluquería y Salón",
      icon: "scissors",
      parent: personal_care_category
    )

    user.categories.find_or_create_by(
      name: "Cosméticos",
      icon: "sparkles",
      parent: personal_care_category
    )

    user.categories.find_or_create_by(
      name: "Spa y Masajes",
      icon: "heart",
      parent: personal_care_category
    )

    # ========================================
    # ENTERTAINMENT
    # ========================================
    entertainment_category = user.categories.find_or_create_by(
      name: "Entretenimiento",
      icon: "film"
    )

    user.categories.find_or_create_by(
      name: "Cine y Teatro",
      icon: "film",
      parent: entertainment_category
    )

    user.categories.find_or_create_by(
      name: "Conciertos y Eventos",
      icon: "music",
      parent: entertainment_category
    )

    user.categories.find_or_create_by(
      name: "Deportes y Actividades",
      icon: "dumbbell",
      parent: entertainment_category
    )

    user.categories.find_or_create_by(
      name: "Viajes",
      icon: "plane",
      parent: entertainment_category
    )

    user.categories.find_or_create_by(
      name: "Hobbies",
      icon: "star",
      parent: entertainment_category
    )

    user.categories.find_or_create_by(
      name: "Videojuegos",
      icon: "gamepad-2",
      parent: entertainment_category
    )

    user.categories.find_or_create_by(
      name: "Libros y Revistas",
      icon: "book",
      parent: entertainment_category
    )

    # ========================================
    # SUBSCRIPTIONS
    # ========================================
    subscriptions_category = user.categories.find_or_create_by(
      name: "Suscripciones",
      icon: "monitor"
    )

    user.categories.find_or_create_by(
      name: "Streaming (Netflix, Spotify, etc)",
      icon: "tv",
      parent: subscriptions_category
    )

    user.categories.find_or_create_by(
      name: "Software y Apps",
      icon: "smartphone",
      parent: subscriptions_category
    )

    user.categories.find_or_create_by(
      name: "Membresías",
      icon: "star",
      parent: subscriptions_category
    )

    user.categories.find_or_create_by(
      name: "Noticias y Publicaciones",
      icon: "book-open",
      parent: subscriptions_category
    )

    # ========================================
    # EDUCATION
    # ========================================
    education_category = user.categories.find_or_create_by(
      name: "Educación",
      icon: "graduation-cap"
    )

    user.categories.find_or_create_by(
      name: "Matrícula Escolar",
      icon: "graduation-cap",
      parent: education_category
    )

    user.categories.find_or_create_by(
      name: "Cursos y Talleres",
      icon: "book-open",
      parent: education_category
    )

    user.categories.find_or_create_by(
      name: "Libros y Material Escolar",
      icon: "pencil",
      parent: education_category
    )

    user.categories.find_or_create_by(
      name: "Tutorías",
      icon: "book",
      parent: education_category
    )

    # ========================================
    # PETS
    # ========================================
    pets_category = user.categories.find_or_create_by(
      name: "Mascotas",
      icon: "dog"
    )

    user.categories.find_or_create_by(
      name: "Comida para Mascotas",
      icon: "dog",
      parent: pets_category
    )

    user.categories.find_or_create_by(
      name: "Veterinario",
      icon: "hospital",
      parent: pets_category
    )

    user.categories.find_or_create_by(
      name: "Accesorios y Suministros",
      icon: "package",
      parent: pets_category
    )

    user.categories.find_or_create_by(
      name: "Seguro de Mascota",
      icon: "shield",
      parent: pets_category
    )

    # ========================================
    # SAVINGS & INVESTMENTS
    # ========================================
    savings_category = user.categories.find_or_create_by(
      name: "Ahorros e Inversiones",
      icon: "piggy-bank"
    )

    user.categories.find_or_create_by(
      name: "Cuenta de Ahorros",
      icon: "piggy-bank",
      parent: savings_category
    )

    user.categories.find_or_create_by(
      name: "Inversiones",
      icon: "chart-bar",
      parent: savings_category
    )

    user.categories.find_or_create_by(
      name: "Fondo de Emergencia",
      icon: "shield",
      parent: savings_category
    )

    user.categories.find_or_create_by(
      name: "Retiro/Pensión",
      icon: "landmark",
      parent: savings_category
    )

    user.categories.find_or_create_by(
      name: "Fondo de Vacaciones",
      icon: "plane",
      parent: savings_category
    )

    # ========================================
    # VACATIONS
    # ========================================
    vacations_category = user.categories.find_or_create_by(
      name: "Vacaciones",
      icon: "palmtree"
    )

    user.categories.find_or_create_by(
      name: "Alojamiento",
      icon: "hotel",
      parent: vacations_category
    )

    user.categories.find_or_create_by(
      name: "Vuelos",
      icon: "plane",
      parent: vacations_category
    )

    user.categories.find_or_create_by(
      name: "Transporte Local",
      icon: "car",
      parent: vacations_category
    )

    user.categories.find_or_create_by(
      name: "Comidas y Restaurantes",
      icon: "utensils",
      parent: vacations_category
    )

    user.categories.find_or_create_by(
      name: "Actividades y Tours",
      icon: "ticket",
      parent: vacations_category
    )

    user.categories.find_or_create_by(
      name: "Souvenirs",
      icon: "gift",
      parent: vacations_category
    )

    user.categories.find_or_create_by(
      name: "Seguro de Viaje",
      icon: "shield",
      parent: vacations_category
    )

    # ========================================
    # DEBTS & LOANS
    # ========================================
    debts_category = user.categories.find_or_create_by(
      name: "Deudas y Préstamos",
      icon: "credit-card"
    )

    user.categories.find_or_create_by(
      name: "Tarjetas de Crédito",
      icon: "credit-card",
      parent: debts_category
    )

    user.categories.find_or_create_by(
      name: "Préstamos Personales",
      icon: "banknote",
      parent: debts_category
    )

    user.categories.find_or_create_by(
      name: "Préstamo Estudiantil",
      icon: "graduation-cap",
      parent: debts_category
    )

    user.categories.find_or_create_by(
      name: "Crédito Automotriz",
      icon: "car",
      parent: debts_category
    )

    user.categories.find_or_create_by(
      name: "Línea de Crédito",
      icon: "wallet",
      parent: debts_category
    )

    user.categories.find_or_create_by(
      name: "Otras Deudas",
      icon: "circle-dot",
      parent: debts_category
    )

    # ========================================
    # TAXES & FEES
    # ========================================
    taxes_category = user.categories.find_or_create_by(
      name: "Impuestos y Comisiones",
      icon: "receipt"
    )

    user.categories.find_or_create_by(
      name: "Impuestos",
      icon: "calculator",
      parent: taxes_category
    )

    user.categories.find_or_create_by(
      name: "Comisiones Bancarias",
      icon: "credit-card",
      parent: taxes_category
    )

    user.categories.find_or_create_by(
      name: "Cargos por Servicios",
      icon: "receipt",
      parent: taxes_category
    )

    user.categories.find_or_create_by(
      name: "Multas y Penalidades",
      icon: "alert-triangle",
      parent: taxes_category
    )

    # ========================================
    # TRANSFERS & PAYMENTS
    # ========================================
    transfers_category = user.categories.find_or_create_by(
      name: "Transferencias",
      icon: "arrow-left-right"
    )

    user.categories.find_or_create_by(
      name: "Transferencias Bancarias",
      icon: "arrow-left-right",
      parent: transfers_category
    )

    user.categories.find_or_create_by(
      name: "Pagos de Deudas",
      icon: "credit-card",
      parent: transfers_category
    )

    user.categories.find_or_create_by(
      name: "Préstamos a Terceros",
      icon: "banknote",
      parent: transfers_category
    )

    # ========================================
    # INSURANCE
    # ========================================
    insurance_category = user.categories.find_or_create_by(
      name: "Seguros",
      icon: "shield"
    )

    user.categories.find_or_create_by(
      name: "Seguro de Vida",
      icon: "heart",
      parent: insurance_category
    )

    user.categories.find_or_create_by(
      name: "Seguro de Salud",
      icon: "heart-pulse",
      parent: insurance_category
    )

    user.categories.find_or_create_by(
      name: "Seguro del Hogar",
      icon: "home",
      parent: insurance_category
    )

    user.categories.find_or_create_by(
      name: "Seguro de Auto",
      icon: "car",
      parent: insurance_category
    )

    user.categories.find_or_create_by(
      name: "Otros Seguros",
      icon: "shield",
      parent: insurance_category
    )

    # ========================================
    # CHILDREN & FAMILY
    # ========================================
    family_category = user.categories.find_or_create_by(
      name: "Familia e Hijos",
      icon: "users"
    )

    user.categories.find_or_create_by(
      name: "Guardería y Cuidado Infantil",
      icon: "baby",
      parent: family_category
    )

    user.categories.find_or_create_by(
      name: "Pañales y Suministros para Bebé",
      icon: "baby",
      parent: family_category
    )

    user.categories.find_or_create_by(
      name: "Ropa para Niños",
      icon: "shirt",
      parent: family_category
    )

    user.categories.find_or_create_by(
      name: "Juguetes",
      icon: "gamepad-2",
      parent: family_category
    )

    user.categories.find_or_create_by(
      name: "Actividades Extracurriculares",
      icon: "award",
      parent: family_category
    )

    user.categories.find_or_create_by(
      name: "Pensión Alimenticia",
      icon: "banknote",
      parent: family_category
    )

    # ========================================
    # CHARITY & DONATIONS
    # ========================================
    charity_category = user.categories.find_or_create_by(
      name: "Caridad y Donaciones",
      icon: "heart-handshake"
    )

    user.categories.find_or_create_by(
      name: "Donaciones",
      icon: "hand-heart",
      parent: charity_category
    )

    user.categories.find_or_create_by(
      name: "Iglesia/Templo",
      icon: "church",
      parent: charity_category
    )

    user.categories.find_or_create_by(
      name: "Organizaciones sin Fines de Lucro",
      icon: "users",
      parent: charity_category
    )

    # ========================================
    # BUSINESS EXPENSES
    # ========================================
    business_category = user.categories.find_or_create_by(
      name: "Gastos de Negocio",
      icon: "briefcase"
    )

    user.categories.find_or_create_by(
      name: "Oficina y Suministros",
      icon: "package",
      parent: business_category
    )

    user.categories.find_or_create_by(
      name: "Marketing y Publicidad",
      icon: "megaphone",
      parent: business_category
    )

    user.categories.find_or_create_by(
      name: "Viajes de Negocio",
      icon: "plane",
      parent: business_category
    )

    user.categories.find_or_create_by(
      name: "Software y Herramientas",
      icon: "laptop",
      parent: business_category
    )

    user.categories.find_or_create_by(
      name: "Servicios Profesionales",
      icon: "user-check",
      parent: business_category
    )

    user.categories.find_or_create_by(
      name: "Comidas de Negocio",
      icon: "utensils",
      parent: business_category
    )

    # ========================================
    # LEGAL & PROFESSIONAL
    # ========================================
    legal_category = user.categories.find_or_create_by(
      name: "Legal y Profesional",
      icon: "scale"
    )

    user.categories.find_or_create_by(
      name: "Abogado",
      icon: "scale",
      parent: legal_category
    )

    user.categories.find_or_create_by(
      name: "Contador",
      icon: "calculator",
      parent: legal_category
    )

    user.categories.find_or_create_by(
      name: "Asesor Financiero",
      icon: "chart-bar",
      parent: legal_category
    )

    user.categories.find_or_create_by(
      name: "Notario",
      icon: "file-text",
      parent: legal_category
    )

    # ========================================
    # MISCELLANEOUS
    # ========================================
    user.categories.find_or_create_by(
      name: "Otros Gastos",
      icon: "circle-dot"
    )
  end
end
