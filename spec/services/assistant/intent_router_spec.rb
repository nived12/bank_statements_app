# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::IntentRouter do
  describe ".classify" do
    deterministic_cases = {
      monthly_summary: [
        "¿Qué cambió este mes?",
        "What changed this month?",
        "Dame el resumen del mes",
        "How was my month?"
      ],
      top_categories: [
        "¿En qué gasto más?",
        "Where do I spend the most?",
        "¿Cuál es mi mayor gasto?",
        "what is my biggest expense?"
      ],
      spending_trend: [
        "¿Cómo va mi tendencia?",
        "spending trend lately?",
        "Am I spending more?"
      ],
      debt_payoff: [
        "¿Cuándo termino de pagar mi deuda?",
        "When will I pay off my debt?",
        "payoff date please"
      ],
      goal_progress: [
        "¿Cuánto me falta para mi meta?",
        "how close am I to my goal?",
        "goal progress?"
      ],
      account_balance: [
        "¿Cuál es mi saldo?",
        "¿Cuánto tengo en mi cuenta?",
        "what is my balance?",
        "how much do I have"
      ],
      category_compare: [
        "Compara mis categorías",
        "compare my spending in two categories"
      ]
    }

    deterministic_cases.each do |intent, messages|
      messages.each do |msg|
        it "classifies #{msg.inspect} as #{intent}" do
          expect(described_class.classify(msg)).to eq(intent)
        end
      end
    end

    [
      "¿Cómo puedo reducir mi gasto en restaurantes?",
      "How can I save more money?",
      "Dame un plan de 7 días para ahorrar 1000",
      "Give me a plan to cut spending",
      "¿Tienes algún consejo?",
      "any tips for me?"
    ].each do |msg|
      it "classifies #{msg.inspect} as llm_freeform" do
        expect(described_class.classify(msg)).to eq(:llm_freeform)
      end
    end

    it "falls back to llm_freeform on unrelated text" do
      expect(described_class.classify("Hola, ¿cómo estás?")).to eq(:llm_freeform)
    end
  end

  describe "#call" do
    let(:user) { create(:user) }

    it "returns deterministic path for known intent" do
      result = described_class.new(message: "¿Cuál es mi saldo?", user: user).call

      expect(result[:intent]).to eq(:account_balance)
      expect(result[:path]).to eq(:deterministic)
    end

    it "returns llm path for freeform" do
      result = described_class.new(message: "¿Cómo reduzco mi gasto?", user: user).call

      expect(result[:path]).to eq(:llm)
    end

    it "extracts debt_id slot when the message names a debt" do
      debt = create(:debt, user: user, name: "Tarjeta Banamex")

      result = described_class.new(message: "¿Cuándo termino de pagar mi Tarjeta Banamex?", user: user).call

      expect(result[:intent]).to eq(:debt_payoff)
      expect(result[:slots][:debt_id]).to eq(debt.id)
    end
  end
end
