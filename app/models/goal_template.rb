class GoalTemplate
  def self.create_example_goals_for_user(user)
    return if user.goals.any?
    
    # Create example savings goal
    savings_goal = user.goals.create!(
      name: "Ahorrar para Vacaciones - Ejemplo",
      goal_type: "savings_goal",
      start_date: Date.current,
      deadline: 6.months.from_now,
      icon: "plane",
      color: "#3B82F6",
      status: "active",
      notes: "Ejemplo de meta de ahorro. Puedes eliminar este ejemplo cuando crees tus propias metas.",
      goal_calculation_settings: {
        "income" => "positive",
        "expense" => "ignore", 
        "transfer_in" => "positive",
        "transfer_out" => "ignore"
      }
    )
    
    # Create example debt payoff goal
    debt_goal = user.goals.create!(
      name: "Libre de Deudas - Ejemplo",
      goal_type: "debt_payoff",
      debt_strategy: "avalanche",
      start_date: Date.current,
      deadline: 2.years.from_now,
      icon: "shield",
      color: "#10B981",
      status: "active",
      notes: "Ejemplo de meta de pago de deudas usando la estrategia avalancha (pagar la deuda con mayor interés primero).",
      goal_calculation_settings: {
        "income" => "positive",
        "expense" => "negative",
        "transfer_in" => "positive", 
        "transfer_out" => "negative"
      }
    )
    
    # Associate savings with savings goal
    vacation_saving = user.savings.find_by(name: "Fondo de Vacaciones - Ejemplo")
    if vacation_saving
      savings_goal.goal_savings.create!(saving: vacation_saving)
    end
    
    # Associate debts with debt goal
    user.debts.each do |debt|
      debt_goal.goal_debts.create!(debt: debt)
    end
    
    Rails.logger.info "Created 2 example goals for user #{user.id}"
  end
end

