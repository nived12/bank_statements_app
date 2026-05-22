# frozen_string_literal: true

module Assistant
  # Derives a `last_subject` hash from the tool calls (or suggestion key) of the
  # current turn and persists it on the conversation. The next turn's PromptBuilder
  # injects this as a [CONTEXT_HINT] so pronouns like "lo" / "desglósalo" resolve
  # to the right entity without the LLM having to guess from history.
  #
  # Off-topic / greeting turns leave the existing subject unchanged.
  class SubjectTracker < ApplicationService
    PRESERVE_INTENTS = %i[off_topic greeting thanks identity capabilities].freeze

    def initialize(conversation:, intent:, tools_called: [], slots: {}, suggestion_key: nil)
      super()
      @conversation    = conversation
      @intent          = intent.to_s.to_sym
      @tools_called    = Array(tools_called)
      @slots           = slots || {}
      @suggestion_key  = suggestion_key
    end

    def call
      return success(@conversation.last_subject) if @conversation.nil?
      return success(@conversation.last_subject) if PRESERVE_INTENTS.include?(@intent)

      derived = derive_subject
      return success(@conversation.last_subject) if derived.blank?

      @conversation.update_column(:last_subject, derived.stringify_keys)
      success(derived)
    rescue => e
      Rails.logger.warn("Assistant::SubjectTracker failed: #{e.class}: #{e.message}")
      success(@conversation&.last_subject || {})
    end

    private

    def derive_subject
      from_suggestion = subject_from_suggestion
      return from_suggestion if from_suggestion.present?

      subject_from_tools
    end

    def subject_from_suggestion
      return nil if @suggestion_key.blank?

      current_period = Date.current.strftime("%Y-%m")
      case @suggestion_key.to_s
      when "monthly_breakdown", "month_vs_previous", "largest_expenses", "recurring_overview"
        { type: "period", period: current_period }
      when "net_worth_overview"
        { type: "net_worth", period: current_period }
      when "total_debt_summary"
        { type: "debts_overview" }
      when "savings_overview"
        { type: "savings_overview" }
      when "goals_overview"
        { type: "goals_overview" }
      when "previous_month_income"
        prev = (Date.current.beginning_of_month - 1.day).strftime("%Y-%m")
        { type: "period", period: prev }
      end
    end

    def subject_from_tools
      return nil if @tools_called.empty?

      # tools_called is recorded as an array of names or {name, args} hashes
      # depending on the Ai::Client implementation. Handle both shapes.
      last = @tools_called.last
      name, args = extract_name_and_args(last)
      return nil if name.nil?

      case name.to_s
      when "query_transactions"
        period = period_from_args(args)
        if args["category_name"].present?
          { type: "category", name: args["category_name"], period: period }
        elsif args["account_name"].present?
          { type: "account", name: args["account_name"], period: period }
        elsif period.present?
          { type: "period", period: period }
        end
      when "get_category_spending"
        { type: "category", name: args["category_name"], period: period_from_args(args) }
      when "get_period_summary", "compare_periods"
        { type: "period", period: period_label(args["period"] || args["period_a"]) }
      when "get_debts"
        args["debt_name"].present? ? { type: "debt", name: args["debt_name"] } : { type: "debts_overview" }
      when "get_savings"
        args["saving_name"].present? ? { type: "saving", name: args["saving_name"] } : { type: "savings_overview" }
      when "get_goals"
        args["goal_name"].present? ? { type: "goal", name: args["goal_name"] } : { type: "goals_overview" }
      when "get_accounts"
        args["account_name"].present? ? { type: "account", name: args["account_name"] } : nil
      when "get_net_worth"
        { type: "net_worth", period: Date.current.strftime("%Y-%m") }
      when "get_recurring_payments"
        { type: "recurring", period: Date.current.strftime("%Y-%m") }
      when "get_largest_transactions"
        { type: "period", period: period_label(args["period"]) || Date.current.strftime("%Y-%m") }
      end
    end

    def extract_name_and_args(entry)
      case entry
      when String
        [entry, {}]
      when Hash
        h = entry.stringify_keys
        [h["name"] || h["tool"], (h["args"] || h["arguments"] || {}).to_h.stringify_keys]
      else
        [nil, {}]
      end
    end

    def period_from_args(args)
      from = args["date_from"]
      to   = args["date_to"]
      return nil if from.blank? && to.blank?

      # Collapse a same-month range to a YYYY-MM label.
      if from.present? && to.present?
        f = Date.parse(from) rescue nil
        t = Date.parse(to)   rescue nil
        if f && t && f.year == t.year && f.month == t.month
          return f.strftime("%Y-%m")
        end
      end
      [from, to].compact.join("..")
    end

    def period_label(value)
      return nil if value.blank?

      case value.to_s
      when "this_month"  then Date.current.strftime("%Y-%m")
      when "last_month"  then (Date.current.beginning_of_month - 1.day).strftime("%Y-%m")
      when "ytd"         then "YTD-#{Date.current.year}"
      else value.to_s
      end
    end
  end
end
