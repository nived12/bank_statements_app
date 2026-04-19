# frozen_string_literal: true

module Api
  module V1
    class GoalsController < BaseController
      before_action :set_goal, only: [:show, :update, :destroy]

      # GET /api/v1/goals
      def index
        goals = current_user.goals.kept
                             .includes(:savings, :debts)
                             .order(created_at: :desc)

        # Apply status filter
        if params[:status].present? && params[:status] != "all"
          goals = goals.where(status: params[:status])
        end

        # Apply goal_type filter
        if params[:goal_type].present?
          goals = goals.where(goal_type: params[:goal_type])
        end

        # Paginate
        @goals = paginate(goals)
      end

      # GET /api/v1/goals/:id
      def show; end

      # POST /api/v1/goals
      def create
        result = Goals::CreateService.call(current_user, goal_create_params)

        if result.success?
          @goal = result.payload
          assign_associations(@goal)
          @goal.reload
          @message = "Goal created successfully"
          render(:show, status: :created)
        else
          @goal = result.payload || Goal.new
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to create goal",
            status: :unprocessable_content,
            details: format_validation_errors(result.errors)
          )
        end
      end

      # PATCH /api/v1/goals/:id
      def update
        result = Goals::UpdateService.call(@goal, goal_params)

        if result.success?
          @goal = result.payload
          @message = "Goal updated successfully"
          render(:show)
        else
          @goal = result.payload || @goal
          render_error(
            "VALIDATION_ERROR",
            message: "Failed to update goal",
            status: :unprocessable_content,
            details: format_validation_errors(result.errors)
          )
        end
      end

      # DELETE /api/v1/goals/:id
      def destroy
        @goal.discard
        head(:no_content)
      end

      private

      def set_goal
        @goal = current_user.goals.find(params[:id])
      end

      def assign_associations(goal)
        saving_ids = params.dig(:goal, :saving_ids)
        debt_ids = params.dig(:goal, :debt_ids)

        if saving_ids.present?
          savings = current_user.savings.where(id: saving_ids.map(&:to_i))
          goal.savings = savings
        end

        if debt_ids.present?
          debts = current_user.debts.where(id: debt_ids.map(&:to_i))
          goal.debts = debts
        end
      end

      # Params for create — excludes saving_ids/debt_ids (handled via assign_associations)
      def goal_create_params
        params.require(:goal).permit(
          :name,
          :goal_type,
          :start_date,
          :deadline,
          :debt_strategy,
          :color,
          :icon,
          :notes
        )
      end

      # Full params for update — UpdateService handles saving_ids/debt_ids internally
      def goal_params
        params.require(:goal).permit(
          :name,
          :goal_type,
          :start_date,
          :deadline,
          :debt_strategy,
          :color,
          :icon,
          :notes,
          saving_ids: [],
          debt_ids: []
        )
      end
    end
  end
end
