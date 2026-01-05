class SavingTemplate
  def self.create_example_savings_for_user(user)
    # Skip creating example data in test environment
    return if Rails.env.test?
    return if user.savings.any?

    # Get or create example categories
    vacation_category = find_or_create_category(user, "Fondo de Vacaciones", "palmtree")
    emergency_category = find_or_create_category(user, "Fondo de Emergencia", "shield")

    # Create example savings
    saving1 = user.savings.create(
      name: "Fondo de Vacaciones - Ejemplo",
      target_amount: 5000.00,
      current_amount: 0.00,
      icon: "plane",
      color: "#3B82F6",
      status: "active",
      calculation_settings: {
        income: "positive",
        expense: "negative",
        transfer_in: "positive",
        transfer_out: "negative"
      },
      notes: "Ejemplo de ahorro para vacaciones. Puedes eliminar este ejemplo cuando crees tus propios ahorros."
    )

    SavingCategory.create!(saving: saving1, category: vacation_category) if saving1.present?

    saving2 = user.savings.create(
      name: "Fondo de Emergencia - Ejemplo",
      target_amount: 10000.00,
      current_amount: 0.00,
      icon: "shield",
      color: "#10B981",
      status: "active",
      calculation_settings: {
        income: "positive",
        expense: "negative",
        transfer_in: "positive",
        transfer_out: "negative"
      },
      notes: "Ejemplo de fondo de emergencia. Se recomienda tener 3-6 meses de gastos ahorrados."
    )

    SavingCategory.create!(saving: saving2, category: emergency_category) if saving2.present?

    Rails.logger.info "Created 2 example savings for user #{user.id}"
  end

  private

  def self.find_or_create_category(user, name, icon)
    category = user.categories.find_by(name: name)

    unless category
      category = user.categories.create!(
        name: name,
        icon: icon
      )
    end

    category
  end
end
