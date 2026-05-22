# frozen_string_literal: true

module Assistant
  # Builds a condensed JSON snapshot of the user's financial state.
  # Reuses FinancialCalculations + model helpers — no LLM calls.
  # Intended as both routing input and (when truncated) LLM context.
  class ContextAssembler < ApplicationService
    def initialize(user:, reference_month: Date.current.beginning_of_month)
      super()
      @user = user
      @reference_month = reference_month
    end

    def call
      success(build_snapshot)
    rescue => e
      Rails.logger.error("Assistant::ContextAssembler failed: #{e.message}")
      failure("Failed to assemble assistant context")
    end

    private

    attr_reader :user, :reference_month

    def build_snapshot
      this_month     = user.calculate_monthly_summary(reference_month)
      prev_month_ref = reference_month.beginning_of_month - 1.day
      prev_month     = user.calculate_monthly_summary(prev_month_ref)
      categories     = user.calculate_category_summary(reference_month)
      trends         = user.calculate_spending_trends(reference_month)

      account_count       = user.bank_accounts.count
      has_active_debts    = user.debts.where(status: "active").exists?
      has_active_savings  = user.savings.where(status: "active").exists?
      has_active_goals    = user.goals.where(status: "active").exists?

      {
        user: {
          id: user.id,
          locale: user_locale,
          currency: "MXN",
          plan: subscription_plan
        },
        snapshot: {
          today: Date.current.iso8601,
          account_count: account_count,
          has_transactions_this_month: this_month[:has_data] == true,
          has_active_debts: has_active_debts,
          has_active_savings: has_active_savings,
          has_active_goals: has_active_goals
        },
        month: {
          label: reference_month.strftime("%Y-%m"),
          income: this_month[:income].to_f,
          expenses: this_month[:expenses].to_f,
          net: this_month[:net].to_f,
          has_data: this_month[:has_data],
          top_categories: (categories[:categories] || []).first(5).map do |c|
            { id: c[:id], name: c[:name], amount: c[:amount].to_f }
          end
        },
        previous_month: {
          label: prev_month_ref.strftime("%Y-%m"),
          income: prev_month[:income].to_f,
          expenses: prev_month[:expenses].to_f,
          net: prev_month[:net].to_f
        },
        trends: trends.map do |t|
          { month: t[:month], amount: t[:amount].to_f }
        end,
        accounts: user.bank_accounts.includes(:bank).limit(10).map do |a|
          {
            id: a.id,
            name: a.respond_to?(:custom_name) ? a.custom_name : a.bank&.name,
            balance: safe_balance(a),
            currency: "MXN"
          }
        end,
        debts: user.debts.where(status: "active").limit(10).map do |d|
          {
            id: d.id,
            name: d.name,
            balance: d.current_balance.to_f,
            original_amount: d.original_amount.to_f,
            progress_percentage: d.respond_to?(:progress_percentage) ? d.progress_percentage.to_f : nil,
            monthly_payment: safely(d, :calculated_monthly_payment),
            payoff_date: safely(d, :best_payoff_date)
          }
        end,
        savings: user.savings.where(status: "active").limit(10).map do |s|
          {
            id: s.id,
            name: s.name,
            target: s.target_amount.to_f,
            current: s.current_amount.to_f,
            remaining: s.amount_remaining.to_f,
            progress_percentage: s.progress_percentage.to_f
          }
        end,
        goals: user.goals.where(status: "active").limit(10).map do |g|
          {
            id: g.id,
            name: g.name,
            on_track: safely(g, :on_track?),
            projected_completion: safely(g, :projected_completion_date),
            deadline: g.respond_to?(:deadline) ? g.deadline : nil
          }
        end
      }
    end

    def user_locale
      I18n.locale.to_s.start_with?("en") ? "en" : "es-MX"
    end

    def subscription_plan
      return "premium" if user.active_paid_subscription?
      return "trial"   if user.active_trial?

      "free"
    end

    def safe_balance(account)
      account.respond_to?(:effective_balance) ? account.effective_balance.to_f : 0.0
    rescue StandardError
      0.0
    end

    def safely(record, method)
      return nil unless record.respond_to?(method)

      record.public_send(method)
    rescue StandardError
      nil
    end
  end
end
