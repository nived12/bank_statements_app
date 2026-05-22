# frozen_string_literal: true

module Assistant
  module Tools
    class ComparePeriods < Base
      NAME = "compare_periods"
      DESCRIPTION = (
        "Compares income and expenses between two time periods. Returns summaries for each period plus a delta."
      ).freeze
      SCHEMA = {
        type: "object",
        properties: {
          period_a: {
            type: "string",
            enum: %w[this_month last_month two_months_ago],
            description: "First period to compare"
          },
          period_b: {
            type: "string",
            enum: %w[this_month last_month two_months_ago],
            description: "Second period to compare"
          }
        },
        required: %w[period_a period_b]
      }.freeze

      def call
        a_start = period_start(@args[:period_a] || "this_month")
        b_start = period_start(@args[:period_b] || "last_month")

        a = @user.calculate_monthly_summary(a_start)
        b = @user.calculate_monthly_summary(b_start)

        success(
          {
                    a: {
                      period: period_label(a_start),
                      income: a[:income].to_f,
                      expenses: a[:expenses].to_f,
                      net: a[:net].to_f
                    },
                    b: {
                      period: period_label(b_start),
                      income: b[:income].to_f,
                      expenses: b[:expenses].to_f,
                      net: b[:net].to_f
                    },
                    delta: {
                      expenses: (a[:expenses].to_f - b[:expenses].to_f).round(2),
                      income: (a[:income].to_f - b[:income].to_f).round(2),
                      net: (a[:net].to_f - b[:net].to_f).round(2)
                    },
                    currency: "MXN"
                  }
        )
      end

      private

      def period_start(label)
        case label
        when "this_month"     then Date.current.beginning_of_month
        when "last_month"     then (Date.current.beginning_of_month - 1.day).beginning_of_month
        when "two_months_ago" then (Date.current.beginning_of_month - 1.day).beginning_of_month.prev_month
        else Date.current.beginning_of_month
        end
      end

      def period_label(start)
        start.strftime("%B %Y")
      end
    end
  end
end
