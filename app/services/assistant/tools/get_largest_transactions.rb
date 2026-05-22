# frozen_string_literal: true

module Assistant
  module Tools
    class GetLargestTransactions < Base
      NAME = "get_largest_transactions"
      DESCRIPTION = "Returns the N largest transactions for the given period and type (expense or income)."
      SCHEMA = {
        type: "object",
        properties: {
          period: { type: "string", enum: %w[this_month last_month ytd], description: "Time period" },
          type:   { type: "string", enum: %w[expense income], description: "Transaction type (default: expense)" },
          n:      { type: "integer", description: "How many to return (default 5, max 10)" }
        },
        required: []
      }.freeze

      def call
        n      = [(@args[:n] || 5).to_i, 10].min
        period = @args[:period] || "this_month"
        type   = @args[:type] || "expense"

        from, to = period_range(period)

        scope = @user.transactions
                     .where(date: from..to)
                     .includes(:category, :bank_account)

        scope = if type == "income"
          scope.where(transaction_type: "income").order(amount: :desc)
        else
          scope.where(transaction_type: %w[fixed_expense variable_expense]).order(amount: :asc)
        end

        rows = scope.limit(n).map do |tx|
          {
            date: tx.date.iso8601,
            amount: tx.amount.to_f.abs,
            merchant: tx.merchant,
            category: tx.category&.name,
            account: tx.bank_account&.custom_name || tx.bank_account&.account_number,
            transaction_type: tx.transaction_type
          }
        end

        success({ transactions: rows, count: rows.size, period: period, currency: "MXN" })
      end

      private

      def period_range(period)
        case period
        when "last_month"
          s = (Date.current.beginning_of_month - 1.day).beginning_of_month
          [s, s.end_of_month]
        when "ytd"
          [Date.current.beginning_of_year, Date.current]
        else
          s = Date.current.beginning_of_month
          [s, s.end_of_month]
        end
      end
    end
  end
end
