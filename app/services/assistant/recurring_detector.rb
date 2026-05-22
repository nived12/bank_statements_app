# frozen_string_literal: true

module Assistant
  # Detects recurring payments for a user by analyzing merchant groupings.
  # Extracted from Api::V1::TransactionsController#recurring_suggestions.
  #
  # Returns an array of hashes: { merchant:, avg_amount:, frequency_days:, last_seen: }
  class RecurringDetector < ApplicationService
    def initialize(user:, lookback_days: 90)
      super()
      @user = user
      @lookback_days = lookback_days
    end

    def call
      cutoff = @lookback_days.days.ago.to_date

      grouped = @user.transactions
        .where("date >= ?", cutoff)
        .where("COALESCE(NULLIF(TRIM(merchant), ''), NULLIF(TRIM(description), '')) IS NOT NULL")
        .where(transaction_type: %w[variable_expense fixed_expense])
        .group("LOWER(TRIM(COALESCE(NULLIF(TRIM(merchant), ''), description)))")
        .having("COUNT(*) >= 2")
        .select(
          "COALESCE(NULLIF(TRIM(MAX(merchant)), ''), MAX(description)) AS merchant",
          "LOWER(TRIM(COALESCE(NULLIF(TRIM(merchant), ''), description))) AS merchant_key",
          "ROUND(AVG(ABS(amount))::numeric, 2) AS avg_amount",
          "COUNT(*) AS occurrence_count",
          "MAX(date) AS last_seen"
        )
        .order("occurrence_count DESC, MAX(date) DESC")

      results = grouped.map do |row|
        {
          merchant: row.merchant,
          avg_amount: row.avg_amount.to_f,
          frequency_days: compute_frequency_days(row.merchant_key, cutoff),
          last_seen: row.last_seen.to_s
        }
      end

      success(results)
    end

    private

    def compute_frequency_days(merchant_key, cutoff)
      dates = @user.transactions
        .where("date >= ? AND LOWER(TRIM(COALESCE(NULLIF(TRIM(merchant), ''), description))) = ?", cutoff, merchant_key)
        .where(transaction_type: %w[variable_expense fixed_expense])
        .order(:date)
        .pluck(:date)

      return 30 if dates.length < 2

      gaps = dates.each_cons(2).map { |a, b| (b - a).to_i }
      (gaps.sum.to_f / gaps.length).round
    end
  end
end
