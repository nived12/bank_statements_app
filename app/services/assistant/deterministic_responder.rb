# frozen_string_literal: true

module Assistant
  # Renders a localized text response for a deterministic intent by combining:
  #   - existing user calculation methods (FinancialCalculations, Debt/Goal/Saving helpers)
  #   - I18n templates under `assistant.responses.<intent>.*`
  #
  # Returns a Response struct: { text:, next_best_action:, source: }.
  class DeterministicResponder
    Response = Struct.new(:text, :next_best_action, :source, keyword_init: true)

    def initialize(user:, intent:, slots:, context:, locale:)
      @user    = user
      @intent  = intent
      @slots   = slots || {}
      @context = context || {}
      @locale  = normalize_locale(locale)
    end

    def call
      case @intent
      when :greeting, :thanks, :identity, :capabilities
        conversational_response
      when :off_topic        then off_topic_response
      when :monthly_summary  then monthly_summary_response
      when :top_categories   then top_categories_response
      when :spending_trend   then spending_trend_response
      when :debt_payoff      then debt_payoff_response
      when :goal_progress    then goal_progress_response
      when :account_balance  then account_balance_response
      when :category_compare then category_compare_response
      else
        Response.new(text: t("assistant.responses.fallback"), next_best_action: nil, source: :deterministic)
      end
    end

    private

    def off_topic_response
      Response.new(
        text: t("assistant.responses.off_topic"),
        next_best_action: nil,
        source: :deterministic
      )
    end

    # Renders the canned 3-part response (headline / actions / next) for any
    # conversational intent. Copy lives in assistant.{en,es}.yml; trigger
    # phrases live in config/assistant/intent_phrases.yml.
    def conversational_response
      Response.new(
        text: format_three_part(
          t("assistant.responses.#{@intent}.headline"),
          t("assistant.responses.#{@intent}.actions"),
          t("assistant.responses.#{@intent}.next")
        ),
        next_best_action: nil,
        source: :deterministic
      )
    end

    def monthly_summary_response
      month = @context[:month] || {}
      prev  = @context[:previous_month] || {}
      headline = t(
        "assistant.responses.monthly_summary.headline",
        expenses: fmt(month[:expenses]),
        income: fmt(month[:income]),
        net: fmt(month[:net]),
        prev_expenses: fmt(prev[:expenses])
      )
      Response.new(
        text: format_three_part(
          headline, t("assistant.responses.monthly_summary.actions"),
          t("assistant.responses.monthly_summary.next")
        ),
        next_best_action: { kind: "open_screen", screen: "dashboard" },
        source: :deterministic
      )
    end

    def top_categories_response
      cats = (@context.dig(:month, :top_categories) || []).first(3)
      top  = cats.first
      headline =
        if top
          t("assistant.responses.top_categories.headline", name: top[:name], amount: fmt(top[:amount]))
        else
          t("assistant.responses.top_categories.no_data")
        end

      action = top && top[:id] ? { kind: "open_screen", screen: "categories", params: { id: top[:id] } } : nil
      Response.new(
        text: format_three_part(
          headline, t("assistant.responses.top_categories.actions"),
          t("assistant.responses.top_categories.next")
        ),
        next_best_action: action,
        source: :deterministic
      )
    end

    def spending_trend_response
      trends = @context[:trends] || []
      direction =
        if trends.length >= 2
          last = trends.last[:amount].to_f
          prev = trends[-2][:amount].to_f
          if last > prev * 1.05
            t("assistant.responses.spending_trend.up")
          elsif last < prev * 0.95
            t("assistant.responses.spending_trend.down")
          else
            t("assistant.responses.spending_trend.flat")
          end
        else
          t("assistant.responses.spending_trend.insufficient")
        end

      headline = t("assistant.responses.spending_trend.headline", direction: direction)
      Response.new(
        text: format_three_part(
          headline, t("assistant.responses.spending_trend.actions"),
          t("assistant.responses.spending_trend.next")
        ),
        next_best_action: { kind: "open_screen", screen: "dashboard" },
        source: :deterministic
      )
    end

    def debt_payoff_response
      debt = resolve_debt
      unless debt
        return Response.new(
          text: t("assistant.responses.debt_payoff.no_data"),
          next_best_action: { kind: "open_screen", screen: "finances" },
          source: :deterministic
        )
      end

      payoff = safely(debt, :best_payoff_date)
      headline = t(
        "assistant.responses.debt_payoff.headline",
        name: debt.name,
        date: payoff ? I18n.l(
          payoff.to_date, format: :long,
          locale: @locale
        ) : t("assistant.responses.debt_payoff.unknown_date"),
        balance: fmt(debt.current_balance)
      )
      Response.new(
        text: format_three_part(
          headline, t("assistant.responses.debt_payoff.actions"),
          t("assistant.responses.debt_payoff.next")
        ),
        next_best_action: { kind: "open_screen", screen: "finances/debts", params: { id: debt.id } },
        source: :deterministic
      )
    end

    def goal_progress_response
      goal = resolve_goal
      unless goal
        return Response.new(
          text: t("assistant.responses.goal_progress.no_data"),
          next_best_action: { kind: "open_screen", screen: "finances" },
          source: :deterministic
        )
      end

      pct = safely(goal, :progress_percentage).to_f
      remaining = safely(goal, :amount_remaining)
      headline = t(
        "assistant.responses.goal_progress.headline",
        name: goal.name,
        percent: pct.round,
        remaining: fmt(remaining)
      )
      Response.new(
        text: format_three_part(
          headline, t("assistant.responses.goal_progress.actions"),
          t("assistant.responses.goal_progress.next")
        ),
        next_best_action: { kind: "open_screen", screen: "finances/goals", params: { id: goal.id } },
        source: :deterministic
      )
    end

    def account_balance_response
      account = resolve_account
      unless account
        return Response.new(
          text: t("assistant.responses.account_balance.no_data"),
          next_best_action: { kind: "open_screen", screen: "accounts" },
          source: :deterministic
        )
      end

      balance = account.respond_to?(:effective_balance) ? account.effective_balance : 0
      display_name = account.respond_to?(:custom_name) ? account.custom_name : account.id
      headline = t("assistant.responses.account_balance.headline", name: display_name, amount: fmt(balance))
      Response.new(
        text: format_three_part(
          headline, t("assistant.responses.account_balance.actions"),
          t("assistant.responses.account_balance.next")
        ),
        next_best_action: { kind: "open_screen", screen: "accounts", params: { id: account.id } },
        source: :deterministic
      )
    end

    def category_compare_response
      cats = (@context.dig(:month, :top_categories) || []).first(2)
      if cats.length < 2
        return Response.new(
          text: t("assistant.responses.category_compare.no_data"),
          next_best_action: nil,
          source: :deterministic
        )
      end

      a, b = cats
      headline = t(
        "assistant.responses.category_compare.headline",
        a: a[:name], a_amount: fmt(a[:amount]),
        b: b[:name], b_amount: fmt(b[:amount])
      )
      Response.new(
        text: format_three_part(
          headline, t("assistant.responses.category_compare.actions"),
          t("assistant.responses.category_compare.next")
        ),
        next_best_action: a[:id] ? { kind: "open_screen", screen: "categories", params: { id: a[:id] } } : nil,
        source: :deterministic
      )
    end

    def resolve_debt
      if @slots[:debt_id]
        @user.debts.find_by(id: @slots[:debt_id])
      else
        @user.debts.where(status: "active").order(current_balance: :desc).first
      end
    end

    def resolve_goal
      if @slots[:goal_id]
        @user.goals.find_by(id: @slots[:goal_id])
      else
        @user.goals.where(status: "active").first
      end
    end

    def resolve_account
      if @slots[:account_id]
        @user.bank_accounts.find_by(id: @slots[:account_id])
      else
        @user.bank_accounts.first
      end
    end

    def t(key, **opts)
      I18n.t(key, locale: @locale, **opts)
    end

    def fmt(amount)
      n = amount.to_f
      negative = n < 0
      formatted = format("%0.2f", n.abs).reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      "#{negative ? "-" : ""}$#{formatted} MXN"
    end

    def format_three_part(headline, actions, next_step)
      [headline, actions, next_step].compact.reject(&:blank?).join("\n\n")
    end

    # The Rails I18n stack uses :en and :es. The conversation locale "es-MX" maps to :es.
    def normalize_locale(loc)
      loc.to_s.start_with?("en") ? :en : :es
    end

    def safely(record, method)
      return nil unless record.respond_to?(method)

      record.public_send(method)
    rescue StandardError
      nil
    end
  end
end
