# frozen_string_literal: true

module Assistant
  # Handles the 9 deterministic suggestion chip shortcuts.
  # Each chip bypasses IntentRouter entirely — $0, <100ms response.
  class SuggestionResponder
    Response = Struct.new(:text, :next_best_action, :source, keyword_init: true)

    KEYS = %w[
      monthly_breakdown
      net_worth_overview
      largest_expenses
      total_debt_summary
      savings_overview
      goals_overview
      month_vs_previous
      recurring_overview
      previous_month_income
    ].freeze

    def initialize(user:, key:, locale:)
      @user   = user
      @key    = key
      @locale = normalize_locale(locale)
    end

    def call
      raise ArgumentError, "unknown suggestion key: #{@key}" unless KEYS.include?(@key)

      send(:"respond_#{@key}")
    end

    private

    # ── 1. Monthly breakdown ────────────────────────────────────────────────

    def respond_monthly_breakdown
      summary = @user.calculate_monthly_summary(Date.current.beginning_of_month)
      unless summary[:has_data]
        return Response.new(
          text: t("assistant.suggestions.monthly_breakdown.empty"),
          next_best_action: { kind: "open_screen", screen: "transactions" },
          source: :deterministic
        )
      end

      cats = @user.calculate_category_summary(Date.current.beginning_of_month)[:categories].first(3)
      top_cats = cats.map { |c| "#{c[:name]} #{fmt(c[:amount])}" }.join(", ")
      top_cats = t("assistant.suggestions.monthly_breakdown.no_categories") if top_cats.blank?

      text = t(
        "assistant.suggestions.monthly_breakdown.response",
        month_label: month_label(Date.current),
        expenses: fmt(summary[:expenses]),
        income: fmt(summary[:income]),
        net: fmt(summary[:net]),
        top_categories: top_cats
      )

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "dashboard" },
        source: :deterministic
      )
    end

    # ── 2. Net worth overview ───────────────────────────────────────────────

    def respond_net_worth_overview
      accounts = @user.bank_accounts.to_a

      if accounts.empty? && @user.debts.where(status: "active").empty?
        return Response.new(
          text: t("assistant.suggestions.net_worth_overview.empty"),
          next_best_action: { kind: "open_screen", screen: "accounts" },
          source: :deterministic
        )
      end

      assets, cc_debt, debit_overdraft, loan_debt = compute_net_worth_components(accounts)
      liabilities = cc_debt + debit_overdraft + loan_debt
      total = assets - liabilities

      text = t(
        "assistant.suggestions.net_worth_overview.response",
        total: fmt(total),
        assets: fmt(assets),
        liabilities: fmt(liabilities),
        credit_card_debt: fmt(cc_debt),
        loan_debt: fmt(loan_debt)
      )

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "accounts" },
        source: :deterministic
      )
    end

    # ── 3. Largest expenses ─────────────────────────────────────────────────

    def respond_largest_expenses
      month = Date.current.beginning_of_month
      txns = @user.transactions
                  .where(date: month..month.end_of_month)
                  .where(transaction_type: %w[fixed_expense variable_expense])
                  .order(amount: :asc)
                  .limit(5)
                  .includes(:category)

      if txns.empty?
        return Response.new(
          text: t("assistant.suggestions.largest_expenses.empty"),
          next_best_action: { kind: "open_screen", screen: "transactions" },
          source: :deterministic
        )
      end

      list = txns.map do |tx|
        cat_name = tx.category&.name || t("assistant.suggestions.largest_expenses.uncategorized")
        t(
          "assistant.suggestions.largest_expenses.list_item",
          date: I18n.l(tx.date, format: :short, locale: @locale),
          amount: fmt(tx.amount.abs),
          merchant: tx.merchant.presence || t("assistant.suggestions.largest_expenses.unknown_merchant"),
          category: cat_name
        )
      end.join("\n")

      text = t(
        "assistant.suggestions.largest_expenses.response",
        month_label: month_label(Date.current),
        list: list
      )

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "transactions" },
        source: :deterministic
      )
    end

    # ── 4. Total debt summary ───────────────────────────────────────────────

    def respond_total_debt_summary
      accounts  = @user.bank_accounts.to_a
      cc_debt   = accounts.select { |a| a.account_type == "credit" }
                          .sum { |a| [-a.effective_balance.to_f, 0].max }
      loans     = @user.debts.where(status: "active")
      loan_debt = loans.sum(:current_balance).to_f
      total     = cc_debt + loan_debt

      if total.zero? && loans.empty?
        return Response.new(
          text: t("assistant.suggestions.total_debt_summary.empty"),
          next_best_action: { kind: "open_screen", screen: "finances" },
          source: :deterministic
        )
      end

      loan_phrase = t("assistant.suggestions.total_debt_summary.loan_phrase", count: loans.count)
      text = t(
        "assistant.suggestions.total_debt_summary.response",
        total: fmt(total),
        loan_debt: fmt(loan_debt),
        loan_phrase: loan_phrase,
        credit_card_debt: fmt(cc_debt)
      )

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "finances" },
        source: :deterministic
      )
    end

    # ── 5. Savings overview ─────────────────────────────────────────────────

    def respond_savings_overview
      savings = @user.savings.where(status: "active").order(:created_at).to_a

      if savings.empty?
        return Response.new(
          text: t("assistant.suggestions.savings_overview.empty"),
          next_best_action: { kind: "open_screen", screen: "finances" },
          source: :deterministic
        )
      end

      total_saved = savings.sum { |s| s.current_amount.to_f }

      list = savings.map do |s|
        remaining_display = [s.amount_remaining.to_f, 0].max
        t(
          "assistant.suggestions.savings_overview.list_item",
          name: s.name,
          pct: s.progress_percentage.to_i,
          current: fmt(s.current_amount),
          target: fmt(s.target_amount),
          remaining: fmt(remaining_display)
        )
      end.join("\n")

      text = t(
        "assistant.suggestions.savings_overview.response",
        count: savings.size,
        total_saved: fmt(total_saved),
        list: list
      )

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "finances" },
        source: :deterministic
      )
    end

    # ── 6. Goals overview ───────────────────────────────────────────────────

    def respond_goals_overview
      goals = @user.goals.where(status: "active").to_a

      if goals.empty?
        return Response.new(
          text: t("assistant.suggestions.goals_overview.empty"),
          next_best_action: { kind: "open_screen", screen: "finances" },
          source: :deterministic
        )
      end

      list = goals.map do |g|
        status_key     = g.on_track? ? "status_on_track" : "status_behind"
        on_track_label = t("assistant.suggestions.goals_overview.#{status_key}")
        projected = g.respond_to?(:projected_completion_date) && g.projected_completion_date
        if projected
          t(
            "assistant.suggestions.goals_overview.list_item",
            name: g.name,
            pct: g.progress_percentage.to_i,
            status_label: on_track_label,
            projected_date: I18n.l(projected.to_date, format: :long, locale: @locale)
          )
        else
          status_label = t("assistant.suggestions.goals_overview.status_no_deadline")
          t(
            "assistant.suggestions.goals_overview.list_item_no_date",
            name: g.name,
            pct: g.progress_percentage.to_i,
            status_label: status_label
          )
        end
      end.join("\n")

      text = t(
        "assistant.suggestions.goals_overview.response",
        count: goals.size,
        list: list
      )

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "finances" },
        source: :deterministic
      )
    end

    # ── 7. Month vs previous ────────────────────────────────────────────────

    def respond_month_vs_previous
      this_m = @user.calculate_monthly_summary(Date.current.beginning_of_month)
      prev_date = Date.current.beginning_of_month - 1.day
      prev_m = @user.calculate_monthly_summary(prev_date)

      unless this_m[:has_data] || prev_m[:has_data]
        return Response.new(
          text: t("assistant.suggestions.month_vs_previous.empty"),
          next_best_action: { kind: "open_screen", screen: "transactions" },
          source: :deterministic
        )
      end

      delta_abs = (this_m[:expenses] - prev_m[:expenses]).abs
      dir_key   = this_m[:expenses] > prev_m[:expenses] ? "direction_more" : "direction_less"
      direction = t("assistant.suggestions.month_vs_previous.#{dir_key}")

      if prev_m[:expenses].to_f.zero?
        text = t(
          "assistant.suggestions.month_vs_previous.response_no_prev_pct",
          this_month_label: month_label(Date.current),
          this_expenses: fmt(this_m[:expenses]),
          prev_month_label: month_label(prev_date)
        )
      else
        delta_pct = ((this_m[:expenses] - prev_m[:expenses]) / prev_m[:expenses].to_f * 100).round
        text = t(
          "assistant.suggestions.month_vs_previous.response_full",
          this_month_label: month_label(Date.current),
          this_expenses: fmt(this_m[:expenses]),
          prev_month_label: month_label(prev_date),
          prev_expenses: fmt(prev_m[:expenses]),
          delta_abs: fmt(delta_abs),
          delta_direction: direction,
          delta_pct: delta_pct.abs
        )
      end

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "dashboard" },
        source: :deterministic
      )
    end

    # ── 8. Recurring overview ───────────────────────────────────────────────

    def respond_recurring_overview
      result = Assistant::RecurringDetector.call(user: @user)
      recurring = result.success? ? result.payload : []

      if recurring.empty?
        return Response.new(
          text: t("assistant.suggestions.recurring_overview.empty"),
          next_best_action: { kind: "open_screen", screen: "transactions" },
          source: :deterministic
        )
      end

      monthly_total = recurring.sum { |r| r[:avg_amount] }

      list = recurring.map do |r|
        t(
          "assistant.suggestions.recurring_overview.list_item",
          merchant: r[:merchant],
          avg_amount: fmt(r[:avg_amount]),
          last_seen: r[:last_seen]
        )
      end.join("\n")

      text = t(
        "assistant.suggestions.recurring_overview.response",
        count: recurring.size,
        list: list,
        monthly_total: fmt(monthly_total)
      )

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "transactions" },
        source: :deterministic
      )
    end

    # ── 9. Previous month income ────────────────────────────────────────────

    def respond_previous_month_income
      prev_date = Date.current.beginning_of_month - 1.day
      prev_m    = @user.calculate_monthly_summary(prev_date)
      this_m    = @user.calculate_monthly_summary(Date.current.beginning_of_month)

      if prev_m[:income].to_f.zero? && prev_m[:income_count].to_i.zero?
        return Response.new(
          text: t("assistant.suggestions.previous_month_income.empty"),
          next_best_action: { kind: "open_screen", screen: "transactions" },
          source: :deterministic
        )
      end

      deposits_phrase = t(
        "assistant.suggestions.previous_month_income.deposits_phrase",
        count: prev_m[:income_count].to_i
      )

      if this_m[:income].to_f.zero?
        text = t(
          "assistant.suggestions.previous_month_income.response_no_current",
          prev_month_label: month_label(prev_date),
          prev_income: fmt(prev_m[:income]),
          deposits_phrase: deposits_phrase,
          this_month_label: month_label(Date.current)
        )
      else
        delta_abs = (prev_m[:income] - this_m[:income]).abs
        dir_key   = prev_m[:income] > this_m[:income] ? "direction_more" : "direction_less"
        direction = t("assistant.suggestions.previous_month_income.#{dir_key}")
        text = t(
          "assistant.suggestions.previous_month_income.response_with_compare",
          prev_month_label: month_label(prev_date),
          prev_income: fmt(prev_m[:income]),
          deposits_phrase: deposits_phrase,
          this_month_label: month_label(Date.current),
          this_income: fmt(this_m[:income]),
          delta_abs: fmt(delta_abs),
          delta_direction: direction
        )
      end

      Response.new(
        text: text,
        next_best_action: { kind: "open_screen", screen: "dashboard" },
        source: :deterministic
      )
    end

    # ── Helpers ─────────────────────────────────────────────────────────────

    def compute_net_worth_components(accounts)
      assets = accounts.sum { |a| [a.effective_balance.to_f, 0].max }
      cc_debt = accounts.select { |a| a.account_type == "credit" }
                        .sum { |a| [-a.effective_balance.to_f, 0].max }
      debit_overdraft = accounts.select { |a| %w[debit cash].include?(a.account_type) }
                                .sum { |a| [-a.effective_balance.to_f, 0].max }
      loan_debt = @user.debts.where(status: "active").sum(:current_balance).to_f
      [assets, cc_debt, debit_overdraft, loan_debt]
    end

    def fmt(amount)
      n = amount.to_f
      negative = n < 0
      formatted = format("%0.2f", n.abs).reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      "#{negative ? "-" : ""}$#{formatted} MXN"
    end

    def month_label(date)
      I18n.l(date.to_date.beginning_of_month, format: :month_year, locale: @locale)
    rescue
      date.to_date.strftime("%B %Y")
    end

    def t(key, **opts)
      I18n.t(key, locale: @locale, **opts)
    end

    def normalize_locale(loc)
      loc.to_s.start_with?("en") ? :en : :es
    end
  end
end
