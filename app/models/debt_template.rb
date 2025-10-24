class DebtTemplate
  def self.create_example_debts_for_user(user)
    return if user.debts.any?

    # Get or create example categories
    credit_card_category = find_or_create_category(user, "Tarjetas de Crédito", "credit-card")
    car_loan_category = find_or_create_category(user, "Crédito Automotriz", "car")

    # Create example debts
    debts_data = [
      {
        name: "Tarjeta de Crédito Principal - Ejemplo",
        original_amount: 5000.00,
        current_balance: 4500.00,
        interest_rate: 18.5,
        minimum_payment: 150.00,
        category: credit_card_category,
        icon: "credit-card",
        color: "#EF4444",
        status: "active",
        calculation_settings: {
          income: "positive",
          expense: "ignore",
          transfer_in: "positive",
          transfer_out: "ignore"
        },
        notes: "Ejemplo de deuda de tarjeta de crédito. Puedes eliminar este ejemplo cuando agregues tus propias deudas."
      },
      {
        name: "Préstamo de Auto - Ejemplo",
        original_amount: 25000.00,
        current_balance: 22000.00,
        interest_rate: 4.5,
        minimum_payment: 450.00,
        category: car_loan_category,
        icon: "car",
        color: "#F97316",
        status: "active",
        calculation_settings: {
          income: "positive",
          expense: "ignore",
          transfer_in: "positive",
          transfer_out: "ignore"
        },
        notes: "Ejemplo de préstamo de auto. Este tipo de deuda generalmente tiene una tasa de interés más baja."
      }
    ]

    debts_data.each do |debt_attrs|
      user.debts.create!(debt_attrs)
    end

    Rails.logger.info "Created #{debts_data.count} example debts for user #{user.id}"
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
