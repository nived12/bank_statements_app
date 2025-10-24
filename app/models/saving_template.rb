class SavingTemplate
  def self.create_example_savings_for_user(user)
    return if user.savings.any?

    # Get or create example categories
    vacation_category = find_or_create_category(user, "Fondo de Vacaciones", "palmtree")
    emergency_category = find_or_create_category(user, "Fondo de Emergencia", "shield")

    # Create example savings
    savings_data = [
      {
        name: "Fondo de Vacaciones - Ejemplo",
        target_amount: 5000.00,
        current_amount: 0.00,
        category: vacation_category,
        icon: "plane",
        color: "#3B82F6",
        status: "active",
        calculation_settings: {
          income: "positive",
          expense: "ignore",
          transfer_in: "positive",
          transfer_out: "ignore"
        },
        notes: "Ejemplo de ahorro para vacaciones. Puedes eliminar este ejemplo cuando crees tus propios ahorros."
      },
      {
        name: "Fondo de Emergencia - Ejemplo",
        target_amount: 10000.00,
        current_amount: 0.00,
        category: emergency_category,
        icon: "shield",
        color: "#10B981",
        status: "active",
        calculation_settings: {
          income: "positive",
          expense: "ignore",
          transfer_in: "positive",
          transfer_out: "ignore"
        },
        notes: "Ejemplo de fondo de emergencia. Se recomienda tener 3-6 meses de gastos ahorrados."
      }
    ]

    savings_data.each do |saving_attrs|
      user.savings.create!(saving_attrs)
    end

    Rails.logger.info "Created #{savings_data.count} example savings for user #{user.id}"
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
