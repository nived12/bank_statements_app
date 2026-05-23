# frozen_string_literal: true

module Assistant
  module Tools
    class GetGoals < Base
      NAME = "get_goals"
      DESCRIPTION = "Returns the user's financial goals with progress, on-track status, and projected completion dates."
      SCHEMA = {
        type: "object",
        properties: {
          status:    { type: "string", enum: %w[active completed all],
description: "Filter by status (default: active)" },
          goal_name: { type: "string", description: "Partial name match for a specific goal" }
        },
        required: []
      }.freeze

      def call
        status = @args[:status] || "active"

        scope = status == "all" ? @user.goals : @user.goals.where(status: status)
        scope = scope.where("name ILIKE ?", "%#{@args[:goal_name]}%") if @args[:goal_name].present?

        goals = scope.map do |g|
          {
            id: g.id,
            name: g.name,
            status: g.status,
            progress_pct: safely(g, :progress_percentage).to_f.round(1),
            on_track: safely(g, :on_track?),
            projected_completion: safely(g, :projected_completion_date)&.iso8601,
            deadline: g.respond_to?(:deadline) ? g.deadline&.iso8601 : nil
          }
        end

        success({ goals: goals, count: goals.size })
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
