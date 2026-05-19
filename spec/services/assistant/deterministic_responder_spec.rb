# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::DeterministicResponder do
  let(:user) { create(:user) }
  let(:default_context) do
    {
      month: {
        label: "2026-05",
        income: 30_000,
        expenses: 18_000,
        net: 12_000,
        top_categories: [
          { id: 1, name: "Restaurantes", amount: 5_000 },
          { id: 2, name: "Transporte",  amount: 3_500 }
        ]
      },
      previous_month: { expenses: 16_000, income: 30_000, net: 14_000 },
      trends: [
        { month: "Mar 2026", amount: 16_000 },
        { month: "Apr 2026", amount: 17_000 },
        { month: "May 2026", amount: 18_000 }
      ],
      accounts: [],
      debts: [],
      savings: [],
      goals: []
    }
  end

  def call_with(intent:, slots: {}, locale: "es-MX", context: default_context)
    described_class.new(
      user: user, intent: intent, slots: slots, context: context, locale: locale
    ).call
  end

  describe ":monthly_summary" do
    it "returns a 3-part response in Spanish by default" do
      r = call_with(intent: :monthly_summary)

      expect(r.text).to include("Este mes gastaste")
      expect(r.text).to include("Acciones:")
      expect(r.text).to include("Próximo paso:")
      expect(r.source).to eq(:deterministic)
    end

    it "responds in English when locale is en" do
      r = call_with(intent: :monthly_summary, locale: "en")

      expect(r.text).to include("This month")
      expect(r.text).to include("Actions:")
      expect(r.text).to include("Next step:")
    end
  end

  describe ":top_categories" do
    it "names the top category and links to it" do
      r = call_with(intent: :top_categories)

      expect(r.text).to include("Restaurantes")
      expect(r.next_best_action[:screen]).to eq("categories")
      expect(r.next_best_action[:params][:id]).to eq(1)
    end

    it "handles no data gracefully" do
      r = call_with(intent: :top_categories, context: default_context.merge(month: { top_categories: [] }))

      expect(r.text).to include("datos")
    end
  end

  describe ":spending_trend" do
    it "describes up/down/flat based on last two trend points" do
      r_up = call_with(
        intent: :spending_trend, context: default_context.merge(
          trends: [
                  { amount: 1_000 }, { amount: 2_000 }
                ]
        )
      )
      expect(r_up.text).to match(/al alza/i)

      r_down = call_with(
        intent: :spending_trend, context: default_context.merge(
          trends: [
                  { amount: 2_000 }, { amount: 1_000 }
                ]
        )
      )
      expect(r_down.text).to match(/a la baja/i)
    end
  end

  describe ":debt_payoff" do
    it "returns no_data when no active debts" do
      r = call_with(intent: :debt_payoff)
      expect(r.text).to include("deudas activas")
    end

    it "uses the user's active debt" do
      debt = create(:debt, user: user, name: "Tarjeta X", current_balance: 5_000, status: "active")
      r = call_with(intent: :debt_payoff, slots: { debt_id: debt.id })

      expect(r.text).to include("Tarjeta X")
      expect(r.next_best_action[:screen]).to eq("finances/debts")
      expect(r.next_best_action[:params][:id]).to eq(debt.id)
    end
  end

  describe ":goal_progress" do
    it "returns no_data when no active goals" do
      r = call_with(intent: :goal_progress)
      expect(r.text).to include("metas activas")
    end
  end

  describe ":account_balance" do
    it "returns no_data when no accounts" do
      r = call_with(intent: :account_balance)
      expect(r.text).to include("cuenta")
    end
  end

  describe ":category_compare" do
    it "compares the top two categories" do
      r = call_with(intent: :category_compare)
      expect(r.text).to include("Restaurantes")
      expect(r.text).to include("Transporte")
    end

    it "returns no_data when fewer than 2 categories" do
      r = call_with(
        intent: :category_compare,
        context: default_context.merge(month: { top_categories: [{ id: 1, name: "X", amount: 100 }] })
      )
      expect(r.text).to include("dos categorías")
    end
  end
end
