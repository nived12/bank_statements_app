# frozen_string_literal: true

module Assistant
  module Tools
    class QueryTransactions < Base
      NAME = "query_transactions"
      DESCRIPTION = (
        "Search or filter the user's transactions by date range, category, account, type, amount range, or keyword. Returns a list with totals." # rubocop:disable Layout/LineLength
      ).freeze
      SCHEMA = {
        type: "object",
        properties: {
          date_from:        { type: "string", description: "Start date ISO 8601 (YYYY-MM-DD)" },
          date_to:          { type: "string", description: "End date ISO 8601 (YYYY-MM-DD)" },
          category_name:    { type: "string", description: "Filter by category name (partial match)" },
          account_name:     { type: "string", description: "Filter by bank account custom name (partial match)" },
          transaction_type: { type: "string", enum: %w[income fixed_expense variable_expense transfer],
description: "Filter by transaction type" },
          min_amount:       { type: "number", description: "Minimum absolute amount in MXN" },
          max_amount:       { type: "number", description: "Maximum absolute amount in MXN" },
          search:           { type: "string", description: "Full-text search across merchant and description" },
          limit:            { type: "integer", description: "Max results to return (default 20)" }
        },
        required: []
      }.freeze

      def call
        scope = @user.transactions.includes(:category, :bank_account)

        scope = scope.where("date >= ?", @args[:date_from]) if @args[:date_from].present?
        scope = scope.where("date <= ?", @args[:date_to]) if @args[:date_to].present?

        if @args[:category_name].present?
          scope = scope.joins(:category).where("categories.name ILIKE ?", "%#{@args[:category_name]}%")
        end

        if @args[:account_name].present?
          scope = scope.joins(:bank_account).where("bank_accounts.custom_name ILIKE ?", "%#{@args[:account_name]}%")
        end

        scope = scope.where(transaction_type: @args[:transaction_type]) if @args[:transaction_type].present?

        if @args[:min_amount].present?
          scope = scope.where("ABS(amount) >= ?", @args[:min_amount].to_f)
        end

        if @args[:max_amount].present?
          scope = scope.where("ABS(amount) <= ?", @args[:max_amount].to_f)
        end

        if @args[:search].present?
          term = "%#{@args[:search]}%"
          scope = scope.where("merchant ILIKE ? OR description ILIKE ?", term, term)
        end

        limit = [(@args[:limit] || 20).to_i, 50].min
        transactions = scope.order(date: :desc).limit(limit)

        rows = transactions.map do |tx|
          {
            id: tx.id,
            date: tx.date.iso8601,
            amount: tx.amount.to_f,
            amount_display: fmt_abs(tx.amount),
            merchant: tx.merchant,
            description: tx.description,
            transaction_type: tx.transaction_type,
            category: tx.category&.name,
            account: tx.bank_account&.custom_name || tx.bank_account&.account_number
          }
        end

        total = transactions.sum(:amount).to_f

        success(
          {
                    transactions: rows,
                    count: rows.size,
                    total_amount: total,
                    total_amount_display: fmt_abs(total),
                    currency: "MXN"
                  }
        )
      end

      private

      def fmt_abs(amount)
        n = amount.to_f.abs
        "$#{format("%.2f", n).reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} MXN"
      end
    end
  end
end
