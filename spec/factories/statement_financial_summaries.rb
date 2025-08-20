FactoryBot.define do
  factory :statement_financial_summary do
    association :statement_file
    statement_type { 'savings' }
    initial_balance { 1000.0 }
    final_balance { 1200.0 }
    statement_period_start { Date.current }
    statement_period_end { Date.current + 30.days }
    days_in_period { 31 }
    total_commissions { 0.0 }
    total_fees { 0.0 }
    statement_type_data { {} }

    trait :credit do
      statement_type { 'credit' }
      initial_balance { 0.0 }
      final_balance { -500.0 }
      statement_type_data do
        {
          'credit_limit' => 10000.0,
          'available_credit' => 9500.0,
          'payment_to_avoid_interest' => 100.0,
          'minimum_payment' => 50.0
        }
      end
    end

    trait :payroll do
      statement_type { 'payroll' }
      statement_type_data do
        {
          'total_deposits' => 5000.0,
          'total_withdrawals' => 2000.0
        }
      end
    end

    trait :same_day_period do
      statement_period_start { Date.current }
      statement_period_end { Date.current }
      days_in_period { 1 }
    end

    trait :with_commissions do
      total_commissions { 25.0 }
      total_fees { 15.0 }
    end
  end
end
