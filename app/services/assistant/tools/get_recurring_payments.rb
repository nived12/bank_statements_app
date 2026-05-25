# frozen_string_literal: true

module Assistant
  module Tools
    class GetRecurringPayments < Base
      NAME = "get_recurring_payments"
      DESCRIPTION = "Returns the user's active recurring transactions (subscriptions and scheduled payments) with monthly + annual totals and the next 30 days of expected cashflow."
      SCHEMA = {
        type: "object",
        properties: {},
        required: []
      }.freeze

      def call
        active = @user.recurring_series.active.order(:next_due_date)

        recurring = active.map do |s|
          {
            id: s.id,
            name: s.name,
            amount: s.expected_amount.to_f,
            frequency: s.frequency,
            next_due_date: s.next_due_date.to_s,
            transaction_type: s.transaction_type,
            monthly_estimate: s.monthly_estimate.to_f
          }
        end

        monthly = active.sum { |s| s.transaction_type == "income" ? -s.monthly_estimate : s.monthly_estimate }
        annual  = active.sum { |s| s.transaction_type == "income" ? -s.annual_estimate  : s.annual_estimate }

        upcoming_30d = active.upcoming_within(30).map do |s|
          { name: s.name, amount: s.expected_amount.to_f, date: s.next_due_date.to_s }
        end

        success(
          recurring_payments: recurring,
          count: recurring.size,
          monthly_total_estimate: monthly.round(2),
          annual_total_estimate: annual.round(2),
          upcoming_next_30_days: upcoming_30d,
          currency: "MXN"
        )
      end
    end
  end
end
