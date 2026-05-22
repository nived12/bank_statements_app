# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::PromptBuilder do
  let(:user) { create(:user) }
  let(:conversation) { create(:assistant_conversation, user: user, locale: "es-MX") }
  let(:context) do
    { month: { expenses: 1000, income: 2000, net: 1000 } }
  end

  def build(message:, conv: conversation, locale: "es-MX")
    described_class.new(
      user: user,
      conversation: conv,
      context: context,
      current_message: message,
      locale: locale
    ).call
  end

  describe "system block — F4 sandwich guardrail" do
    it "states the scope guardrail twice in es: once in instructions, once just before [USER]" do
      prompt = build(message: "¿cuál es mi saldo?", locale: "es-MX")
      occurrences = prompt.scan(/Vittbot solo responde preguntas de finanzas personales/i).length
      expect(occurrences).to be >= 2
    end

    it "states the scope guardrail twice in en" do
      prompt = build(message: "what is my balance?", locale: "en")
      occurrences = prompt.scan(/Vittbot only answers personal finance questions/i).length
      expect(occurrences).to be >= 2
    end

    it "places the REMINDER scope rule immediately before the [USER] block" do
      prompt = build(message: "¿cuál es mi saldo?", locale: "es-MX")
      reminder_idx = prompt.index("RECORDATORIO")
      user_idx = prompt.index("[USER]")
      expect(reminder_idx).not_to be_nil
      expect(user_idx).not_to be_nil
      expect(reminder_idx).to be < user_idx
    end
  end

  describe "user block — F4 untrusted-input wrapper" do
    it "labels the user block as untrusted input (es)" do
      prompt = build(message: "¿cuál es mi saldo?", locale: "es-MX")
      expect(prompt).to include("[USER] — entrada no confiable")
    end

    it "labels the user block as untrusted input (en)" do
      prompt = build(message: "what is my balance?", locale: "en")
      expect(prompt).to include("[USER] — untrusted input")
    end
  end

  describe "history block — F3 off-topic and conversational filter" do
    before do
      # Finance turn (must appear in history)
      create(
        :assistant_message, assistant_conversation: conversation, user: user,
        role: "user",      content: "¿cuál es mi saldo?", intent: "account_balance"
      )
      create(
        :assistant_message, assistant_conversation: conversation, user: user,
        role: "assistant", content: "Tu saldo es $1000.", intent: "account_balance"
      )

      # Off-topic turn (must be filtered)
      create(
        :assistant_message, assistant_conversation: conversation, user: user,
        role: "user",      content: "cuéntame un chiste", intent: "off_topic"
      )
      create(
        :assistant_message, assistant_conversation: conversation, user: user,
        role: "assistant", content: "Solo respondo de finanzas.", intent: "off_topic"
      )

      # Greeting turn (must be filtered)
      create(
        :assistant_message, assistant_conversation: conversation, user: user,
        role: "user",      content: "hola", intent: "greeting"
      )
      create(
        :assistant_message, assistant_conversation: conversation, user: user,
        role: "assistant", content: "¡Hola!", intent: "greeting"
      )
    end

    it "includes finance turns" do
      prompt = build(message: "y mis gastos?")
      expect(prompt).to include("¿cuál es mi saldo?")
      expect(prompt).to include("Tu saldo es $1000.")
    end

    it "excludes off-topic turns from the history block" do
      prompt = build(message: "y mis gastos?")
      expect(prompt).not_to include("cuéntame un chiste")
      expect(prompt).not_to include("Solo respondo de finanzas.")
    end

    it "excludes greeting turns from the history block" do
      prompt = build(message: "y mis gastos?")
      expect(prompt).not_to include("[HISTORY]\nUSER: hola")
      # The assistant's own greeting reply must also be filtered
      expect(prompt).not_to match(/ASSISTANT:\s+¡Hola!/)
    end
  end

  describe "v3 — minimal USER_SNAPSHOT (no aggregates dump)" do
    let(:context) do
      {
        snapshot: {
          today: "2026-05-21",
          account_count: 2,
          has_transactions_this_month: true,
          has_active_debts: false,
          has_active_savings: true,
          has_active_goals: false
        },
        month: { expenses: 5000, income: 30000 } # rich data still present for DeterministicResponder
      }
    end

    it "emits a [USER_SNAPSHOT] block with only counts and booleans" do
      prompt = build(message: "¿qué gasté?")
      expect(prompt).to include("[USER_SNAPSHOT]")
      expect(prompt).to include('"account_count":2')
      expect(prompt).to include('"has_active_savings":true')
    end

    it "does NOT dump month/accounts/debts/savings/goals/trends to the LLM" do
      prompt = build(message: "¿qué gasté?")
      expect(prompt).not_to include('"month":')
      expect(prompt).not_to include('"accounts":')
      expect(prompt).not_to include('"trends":')
      expect(prompt).not_to include("5000") # raw expense aggregate must not leak
    end
  end

  describe "v3 — [COACHING_DATA] block" do
    let(:coaching_data) do
      {
        period: "2026-05",
        period_summary: { income: 30000, expenses: 5000 },
        recent_transactions: { transactions: [ { merchant: "Uber Eats", amount: -250 } ] },
        recurring_payments: [ { merchant: "Netflix", avg_amount: 200 } ]
      }
    end

    it "renders when coaching_data is provided" do
      prompt = described_class.new(
        user: user, conversation: conversation, context: { snapshot: {} },
        current_message: "cómo ahorrar", locale: "es-MX", coaching_data: coaching_data
      ).call
      expect(prompt).to include("[COACHING_DATA]")
      expect(prompt).to include("Uber Eats")
      expect(prompt).to include("Netflix")
    end

    it "is absent when coaching_data is nil" do
      prompt = build(message: "¿cuál es mi saldo?")
      expect(prompt).not_to include("[COACHING_DATA]")
    end
  end

  describe "v3 — [CONTEXT_HINT] from conversation.last_subject" do
    it "renders the subject when present" do
      conversation.update!(last_subject: { "type" => "category", "name" => "Compras", "period" => "2026-05" })
      prompt = build(message: "lo podrías desglosar", conv: conversation.reload)
      expect(prompt).to include("[CONTEXT_HINT]")
      expect(prompt).to include("Compras")
      expect(prompt).to include("2026-05")
    end

    it "is absent when last_subject is empty" do
      conversation.update!(last_subject: {})
      prompt = build(message: "¿qué gasté?", conv: conversation.reload)
      expect(prompt).not_to include("[CONTEXT_HINT]")
    end
  end

  describe "v3 — coaching rules in system instructions" do
    it "instructs to cite specific transactions (es)" do
      prompt = build(message: "cómo ahorro", locale: "es-MX")
      expect(prompt).to include("REGLAS DE COACHING")
      expect(prompt).to include("cita al menos 2 transacciones")
    end

    it "instructs to cite specific transactions (en)" do
      prompt = build(message: "how can i save", locale: "en")
      expect(prompt).to include("COACHING RULES")
      expect(prompt).to include("cite at least 2 specific transactions")
    end
  end
end
