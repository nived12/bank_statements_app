# frozen_string_literal: true

module Assistant
  module Tools
    class GetSavings < Base
      NAME = "get_savings"
      DESCRIPTION = (
        "Returns the user's savings goals (piggy bank / savings funds — NOT debts). Optionally filter by status or name." # rubocop:disable Layout/LineLength
      ).freeze
      SCHEMA = {
        type: "object",
        properties: {
          status:      { type: "string", enum: %w[active completed paused all],
description: "Filter by status (default: active)" },
          saving_name: { type: "string", description: "Partial name match for a specific saving" }
        },
        required: []
      }.freeze

      def call
        status = @args[:status] || "active"

        scope = status == "all" ? @user.savings : @user.savings.where(status: status)
        scope = scope.where("name ILIKE ?", "%#{@args[:saving_name]}%") if @args[:saving_name].present?

        savings = scope.map do |s|
          remaining = [s.amount_remaining.to_f, 0].max
          {
            id: s.id,
            name: s.name,
            status: s.status,
            current_amount: s.current_amount.to_f,
            target_amount: s.target_amount.to_f,
            amount_remaining: remaining,
            progress_pct: s.progress_percentage.to_f.round(1),
            projected_completion: s.respond_to?(:suggested_target_date) ? s.suggested_target_date&.iso8601 : nil
          }
        end

        success(
          {
                    savings: savings,
                    total_saved: savings.sum { |s| s[:current_amount] }.round(2),
                    count: savings.size,
                    currency: "MXN"
                  }
        )
      end
    end
  end
end
