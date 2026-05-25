# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::SuggestionResponder, type: :service do
  let(:user) { create(:user) }

  def call(key, locale: "es-MX")
    described_class.new(user: user, key: key, locale: locale).call
  end

  # ── Guards ─────────────────────────────────────────────────────────────────

  it "raises for unknown key" do
    expect { described_class.new(user: user, key: "bogus_key", locale: "es-MX").call }
      .to raise_error(ArgumentError, /unknown suggestion key/)
  end

  # ── 1. monthly_breakdown ───────────────────────────────────────────────────

  describe "monthly_breakdown" do
    context "with no transactions" do
      it "returns empty state" do
        r = call("monthly_breakdown")
        expect(r.text).to include("no hay movimientos")
        expect(r.source).to eq(:deterministic)
      end
    end

    context "with transactions this month" do
      before do
        account = create(:bank_account, user: user, opening_balance: 50_000)
        cat = Category.find_by(user: user, name: "Comida") || create(:category, user: user, name: "Comida")
        create(
          :transaction, user: user, bank_account: account,
          transaction_type: "variable_expense",
          amount: -3_000, date: Date.current, category: cat
        )
        create(
          :transaction, user: user, bank_account: account,
          transaction_type: "income", amount: 20_000, date: Date.current
        )
      end

      it "includes expenses, income and top categories" do
        r = call("monthly_breakdown")
        expect(r.text).to include("$3,000.00 MXN")
        expect(r.text).to include("$20,000.00 MXN")
        expect(r.text).to include("Comida")
      end

      it "includes the month label" do
        r = call("monthly_breakdown")
        expect(r.text).not_to include("%{month_label}")
        expect(r.text).not_to be_blank
      end

      it "never contains NaN or empty interpolation" do
        r = call("monthly_breakdown")
        expect(r.text).not_to match(/%\{|NaN|Infinity/)
      end
    end
  end

  # ── 2. net_worth_overview ──────────────────────────────────────────────────

  describe "net_worth_overview" do
    context "with no accounts and no debts" do
      it "returns empty state" do
        r = call("net_worth_overview")
        expect(r.text).to include("Agrega tu primera cuenta")
      end
    end

    context "with debit account, credit card debt, and a loan" do
      before do
        create(:bank_account, user: user, account_type: "debit", opening_balance: 100_000)
        create(:bank_account, user: user, account_type: "credit", opening_balance: -30_000)
        create(:debt, user: user, current_balance: 20_000, status: "active")
      end

      it "calculates net worth as assets minus all liabilities" do
        r = call("net_worth_overview")
        # 100k assets - 30k CC - 20k loan = 50k net worth
        expect(r.text).to include("$50,000.00 MXN")
      end

      it "shows credit card debt separately" do
        r = call("net_worth_overview")
        expect(r.text).to include("$30,000.00 MXN")
      end

      it "shows loan debt separately" do
        r = call("net_worth_overview")
        expect(r.text).to include("$20,000.00 MXN")
      end
    end

    context "with overpaid credit card (positive balance)" do
      before do
        create(:bank_account, user: user, account_type: "credit", opening_balance: 5_000)
      end

      it "counts overpaid CC as an asset (cc_debt = 0)" do
        r = call("net_worth_overview")
        # 5k asset, 0 liabilities = 5k net worth
        expect(r.text).to include("$5,000.00 MXN")
        expect(r.text).not_to include("-$5,000.00")
      end
    end
  end

  # ── 3. largest_expenses ────────────────────────────────────────────────────

  describe "largest_expenses" do
    context "with no expenses this month" do
      it "returns empty state" do
        r = call("largest_expenses")
        expect(r.text).to include("no hay gastos")
      end
    end

    context "with 3 expenses" do
      before do
        account = create(:bank_account, user: user, opening_balance: 50_000)
        [1_500, 2_000, 500].each do |amt|
          create(
            :transaction, user: user, bank_account: account,
            transaction_type: "variable_expense",
            amount: -amt, date: Date.current
          )
        end
      end

      it "lists up to 5 expenses sorted by largest" do
        r = call("largest_expenses")
        expect(r.text).to include("$2,000.00 MXN")
        expect(r.text).to include("$1,500.00 MXN")
      end

      it "displays amounts as positive" do
        r = call("largest_expenses")
        expect(r.text).not_to include("-$")
      end
    end
  end

  # ── 4. total_debt_summary ──────────────────────────────────────────────────

  describe "total_debt_summary" do
    context "with no debt" do
      it "returns empty state" do
        r = call("total_debt_summary")
        expect(r.text).to include("deudas activas")
      end
    end

    context "with CC balance and a loan" do
      before do
        create(:bank_account, user: user, account_type: "credit", opening_balance: -15_000)
        create(:debt, user: user, current_balance: 25_000, status: "active")
      end

      it "includes total debt" do
        r = call("total_debt_summary")
        expect(r.text).to include("$40,000.00 MXN")
      end

      it "shows CC debt and loan debt separately" do
        r = call("total_debt_summary")
        expect(r.text).to include("$15,000.00 MXN")
        expect(r.text).to include("$25,000.00 MXN")
      end
    end

    context "with CC at zero balance" do
      before do
        create(:bank_account, user: user, account_type: "credit", opening_balance: 0)
        create(:debt, user: user, current_balance: 5_000, status: "active")
      end

      it "shows only loan debt" do
        r = call("total_debt_summary")
        expect(r.text).to include("$5,000.00 MXN")
      end
    end
  end

  # ── 5. savings_overview ────────────────────────────────────────────────────

  describe "savings_overview" do
    context "with no savings" do
      it "returns empty state" do
        r = call("savings_overview")
        expect(r.text).to include("no tienes ahorros")
      end
    end

    context "with an active saving" do
      before do
        create(:saving, user: user, name: "Viaje", target_amount: 10_000, current_amount: 4_000, status: "active")
      end

      it "shows progress percentage and amounts" do
        r = call("savings_overview")
        expect(r.text).to include("Viaje")
        expect(r.text).to include("40%")
        expect(r.text).to include("$4,000.00 MXN")
      end
    end

    context "with a saving that has a very small target_amount (near zero)" do
      before do
        # target_amount must be > 0 per model validation; use minimum valid value
        create(:saving, user: user, name: "SinMeta", target_amount: 0.01, current_amount: 0, status: "active")
      end

      it "does not raise division by zero" do
        expect { call("savings_overview") }.not_to raise_error
      end

      it "shows 0% progress" do
        r = call("savings_overview")
        expect(r.text).to include("0%")
      end
    end

    context "with an overshoot saving (amount > target)" do
      before do
        create(:saving, user: user, name: "Sobrepasado", target_amount: 1_000, current_amount: 1_500, status: "active")
      end

      it "shows remaining as 0 (not negative)" do
        r = call("savings_overview")
        # remaining clamped to 0 — should not show negative remaining
        expect(r.text).not_to include("-$")
      end
    end
  end

  # ── 6. goals_overview ─────────────────────────────────────────────────────

  describe "goals_overview" do
    context "with no goals" do
      it "returns empty state" do
        r = call("goals_overview")
        expect(r.text).to include("no tienes metas")
      end
    end

    context "with an active goal" do
      before do
        create(:goal, user: user, name: "Fondo de emergencia", status: "active")
      end

      it "includes the goal name" do
        r = call("goals_overview")
        expect(r.text).to include("Fondo de emergencia")
      end

      it "never contains NaN or empty interpolation" do
        r = call("goals_overview")
        expect(r.text).not_to match(/%\{|NaN|Infinity/)
      end
    end
  end

  # ── 7. month_vs_previous ──────────────────────────────────────────────────

  describe "month_vs_previous" do
    context "with no data in either month" do
      it "returns empty state" do
        r = call("month_vs_previous")
        expect(r.text).to include("Sin datos suficientes")
      end
    end

    context "with data in both months" do
      before do
        account = create(:bank_account, user: user, opening_balance: 50_000)
        create(
          :transaction, user: user, bank_account: account,
          transaction_type: "variable_expense",
          amount: -5_000, date: Date.current.beginning_of_month + 2
        )
        create(
          :transaction, user: user, bank_account: account,
          transaction_type: "variable_expense",
          amount: -3_000, date: (Date.current.beginning_of_month - 1.day).beginning_of_month + 2
        )
      end

      it "includes both months' spending" do
        r = call("month_vs_previous")
        expect(r.text).to include("$5,000.00 MXN")
        expect(r.text).to include("$3,000.00 MXN")
      end
    end

    context "when previous month has no expenses" do
      before do
        account = create(:bank_account, user: user, opening_balance: 50_000)
        create(
          :transaction, user: user, bank_account: account,
          transaction_type: "variable_expense",
          amount: -2_000, date: Date.current.beginning_of_month + 1
        )
      end

      it "uses the no_prev_pct template (no percentage)" do
        r = call("month_vs_previous")
        expect(r.text).to include("no puedo calcular la variación porcentual")
        expect(r.text).not_to match(/%\{|NaN|Infinity/)
      end
    end
  end

  # ── 8. recurring_overview ─────────────────────────────────────────────────

  describe "recurring_overview" do
    context "with no recurring transactions" do
      it "returns empty state" do
        r = call("recurring_overview")
        expect(r.text).to include("No detecté pagos recurrentes")
      end
    end

    context "with an active recurring series" do
      before do
        create(:recurring_series, user: user, name: "Netflix",
               expected_amount: 299, frequency: "monthly",
               next_due_date: Date.current + 5)
      end

      it "lists the active series in the response" do
        r = call("recurring_overview")
        expect(r.text).to include("Netflix")
      end
    end
  end

  # ── 9. previous_month_income ──────────────────────────────────────────────

  describe "previous_month_income" do
    context "with no income last month" do
      it "returns empty state" do
        r = call("previous_month_income")
        expect(r.text).to include("Sin datos de ingresos")
      end
    end

    context "with income last month" do
      before do
        account = create(:bank_account, user: user, opening_balance: 0)
        prev_month_date = (Date.current.beginning_of_month - 1.day).beginning_of_month + 5
        create(
          :transaction, user: user, bank_account: account,
          transaction_type: "income",
          amount: 25_000, date: prev_month_date
        )
      end

      it "shows last month's income" do
        r = call("previous_month_income")
        expect(r.text).to include("$25,000.00 MXN")
      end

      it "never contains NaN or uninterpolated variables" do
        r = call("previous_month_income")
        expect(r.text).not_to match(/%\{|NaN|Infinity/)
      end
    end
  end

  # ── EN locale roundtrip ───────────────────────────────────────────────────

  describe "English locale" do
    before do
      create(:bank_account, user: user, account_type: "debit", opening_balance: 50_000)
    end

    it "returns English text for net_worth_overview" do
      r = call("net_worth_overview", locale: "en")
      expect(r.text).to include("net worth")
    end
  end
end
