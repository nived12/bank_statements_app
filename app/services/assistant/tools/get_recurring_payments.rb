# frozen_string_literal: true

module Assistant
  module Tools
    class GetRecurringPayments < Base
      NAME = "get_recurring_payments"
      DESCRIPTION = "Detects recurring payments from the last N days by finding merchants that appear 2+ times."
      SCHEMA = {
        type: "object",
        properties: {
          lookback_days: { type: "integer", description: "How many days back to look (default 90)" }
        },
        required: []
      }.freeze

      def call
        lookback = (@args[:lookback_days] || 90).to_i
        result   = Assistant::RecurringDetector.call(user: @user, lookback_days: lookback)

        recurring = result.success? ? result.payload : []

        success(
          {
                    recurring_payments: recurring,
                    count: recurring.size,
                    monthly_total_estimate: recurring.sum { |r| r[:avg_amount] }.round(2),
                    currency: "MXN"
                  }
        )
      end
    end
  end
end
