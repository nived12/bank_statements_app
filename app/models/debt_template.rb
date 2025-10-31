class DebtTemplate
  def self.create_example_debts_for_user(user)
    return if user.debts.any?

    # Get or create example categories
    credit_card_category = find_or_create_category(user, "Tarjetas de Crédito", "credit-card")
    car_loan_category = find_or_create_category(user, "Crédito Automotriz", "car")

    # Create example debts
    debt1 = user.debts.create(
      name: "Tarjeta de Crédito Principal - Ejemplo",
      original_amount: 5000.00,
      current_balance: 4500.00,
      interest_rate: 18.5,
      minimum_payment: 150.00,
      icon: "credit-card",
      color: "#EF4444",
      status: "active",
      calculation_settings: {
        income: "positive",
        expense: "negative",
        transfer_in: "positive",
        transfer_out: "ignore"
      },
      notes: "Ejemplo de deuda de tarjeta de crédito. Puedes eliminar este ejemplo cuando agregues tus propias deudas."
    )

    DebtCategory.create!(debt: debt1, category: credit_card_category) if debt1.present?

    debt2 = user.debts.create!(
      name: "Crédito de Auto - Ejemplo",
      original_amount: 25000.00,
      current_balance: 22000.00,
      interest_rate: 4.5,
      minimum_payment: 450.00,
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
    )

    DebtCategory.create!(debt: debt2, category: car_loan_category)

    Rails.logger.info "Created 2 example debts for user #{user.id}"
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
