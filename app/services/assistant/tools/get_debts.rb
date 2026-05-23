# frozen_string_literal: true

module Assistant
  module Tools
    class GetDebts < Base
      NAME = "get_debts"
      DESCRIPTION = (
        "Returns the user's loan/credit debts (NOT credit card accounts). Optionally filter by status or debt name."
      ).freeze
      SCHEMA = {
        type: "object",
        properties: {
          status:    { type: "string", enum: %w[active paid_off paused all],
description: "Filter by status (default: active)" },
          debt_name: { type: "string", description: "Partial name match for a specific debt" }
        },
        required: []
      }.freeze

      def call
        status = @args[:status] || "active"

        scope = status == "all" ? @user.debts : @user.debts.where(status: status)
        scope = scope.where("name ILIKE ?", "%#{@args[:debt_name]}%") if @args[:debt_name].present?

        debts = scope.map do |d|
          {
            id: d.id,
            name: d.name,
            status: d.status,
            current_balance: d.current_balance.to_f,
            original_amount: d.original_amount.to_f,
            progress_pct: safely(d, :progress_percentage).to_f.round(1),
            monthly_payment: d.minimum_payment.to_f,
            payoff_date: safely(d, :best_payoff_date)&.iso8601
          }
        end

        success(
          {
                    debts: debts,
                    total_debt: debts.sum { |d| d[:current_balance] }.round(2),
                    count: debts.size,
                    currency: "MXN"
                  }
        )
      end

      private

      def safely(record, method)
        record.public_send(method)
      rescue StandardError
        nil
      end
    end
  end
end
