# frozen_string_literal: true

module Assistant
  module Tools
    class GetPeriodSummary < Base
      NAME = "get_period_summary"
      DESCRIPTION = (
        "Returns income, expenses, net, and top spending categories for a given period. Use 'this_month', 'last_month', 'ytd', or a custom {from, to} date range." # rubocop:disable Layout/LineLength
      ).freeze
      SCHEMA = {
        type: "object",
        properties: {
          period: {
            description: "Period: 'this_month', 'last_month', 'ytd', or {from, to} ISO 8601 dates.", # rubocop:disable Layout/LineLength
            oneOf: [
              { type: "string", enum: %w[this_month last_month ytd] },
              {
                type: "object",
                properties: {
                  from: { type: "string" },
                  to:   { type: "string" }
                },
                required: %w[from to]
              }
            ]
          }
        },
        required: ["period"]
      }.freeze

      def call
        from, to = resolve_period(@args[:period] || "this_month")
        summary  = @user.calculate_monthly_summary(from)
        cats     = @user.calculate_category_summary(from)[:categories].first(5)

        success(
          {
                    period: { from: from.iso8601, to: to.iso8601 },
                    income: summary[:income].to_f,
                    expenses: summary[:expenses].to_f,
                    net: summary[:net].to_f,
                    transaction_count: summary[:count].to_i,
                    top_categories: cats.map { |c| { name: c[:name], amount: c[:amount].to_f } },
                    currency: "MXN",
                    has_data: summary[:has_data]
                  }
        )
      end

      private

      def resolve_period(period)
        case period
        when "this_month"
          start = Date.current.beginning_of_month
          [start, start.end_of_month]
        when "last_month"
          start = (Date.current.beginning_of_month - 1.day).beginning_of_month
          [start, start.end_of_month]
        when "ytd"
          [Date.current.beginning_of_year, Date.current]
        when Hash
          from = Date.parse(period[:from].to_s)
          to   = Date.parse(period[:to].to_s)
          [from, to]
        else
          start = Date.current.beginning_of_month
          [start, start.end_of_month]
        end
      end
    end
  end
end
