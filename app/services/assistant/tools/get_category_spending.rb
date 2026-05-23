# frozen_string_literal: true

module Assistant
  module Tools
    class GetCategorySpending < Base
      NAME = "get_category_spending"
      DESCRIPTION = (
        "Returns total spending for a specific category in the given period, with a sample of transactions and comparison to the previous period." # rubocop:disable Layout/LineLength
      ).freeze
      SCHEMA = {
        type: "object",
        properties: {
          category_name: { type: "string", description: "Category name (partial match)" },
          period: { type: "string", enum: %w[this_month last_month ytd],
description: "Time period (default: this_month)" }
        },
        required: ["category_name"]
      }.freeze

      def call
        return failure("category_name is required") if @args[:category_name].blank?

        period  = @args[:period] || "this_month"
        from, to = period_range(period)

        txns = @user.transactions
                    .joins(:category)
                    .where("categories.name ILIKE ?", "%#{@args[:category_name]}%")
                    .where(date: from..to)
                    .where(transaction_type: %w[fixed_expense variable_expense])
                    .includes(:category)
                    .order(amount: :asc)

        total = txns.sum(:amount).abs.to_f

        prev_from, prev_to = prev_period_range(period)
        prev_txns = @user.transactions
                         .joins(:category)
                         .where("categories.name ILIKE ?", "%#{@args[:category_name]}%")
                         .where(date: prev_from..prev_to)
                         .where(transaction_type: %w[fixed_expense variable_expense])
        prev_total = prev_txns.sum(:amount).abs.to_f

        sample = txns.limit(5).map do |tx|
          {
            date: tx.date.iso8601,
            amount: tx.amount.to_f.abs,
            merchant: tx.merchant,
            category: tx.category&.name
          }
        end

        success(
          {
                    category: @args[:category_name],
                    period: period,
                    total: total.round(2),
                    transaction_count: txns.count,
                    transactions_sample: sample,
                    vs_previous_period: {
                      total: prev_total.round(2),
                      delta: (total - prev_total).round(2)
                    },
                    currency: "MXN"
                  }
        )
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

      def prev_period_range(period)
        case period
        when "last_month"
          s = ((Date.current.beginning_of_month - 1.day).beginning_of_month - 1.day).beginning_of_month
          [s, s.end_of_month]
        when "ytd"
          s = Date.current.beginning_of_year.prev_year
          [s, s.end_of_year]
        else
          s = (Date.current.beginning_of_month - 1.day).beginning_of_month
          [s, s.end_of_month]
        end
      end
    end
  end
end
