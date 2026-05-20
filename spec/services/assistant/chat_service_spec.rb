# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::ChatService do
  let(:user) { create(:user) }

  def make_paid!
    user.update_columns(trial_ends_at: nil)
    customer = create(:pay_customer, owner: user)
    create(:pay_subscription, customer: customer, status: "active")
  end

  before { make_paid! }

  describe "deterministic path" do
    it "answers without calling Ai::Client" do
      expect_any_instance_of(Ai::Client).not_to receive(:chat)

      result = described_class.call(user: user, message: "¿En qué gasto más?", locale: "es-MX")

      expect(result).to be_success
      payload = result.payload
      expect(payload.assistant_message.is_deterministic).to be true
      expect(payload.assistant_message.intent).to eq("top_categories")
      expect(payload.user_message.role).to eq("user")
      expect(payload.assistant_message.role).to eq("assistant")
    end

    it "persists both user and assistant messages" do
      expect {
        described_class.call(user: user, message: "¿Cuál es mi saldo?", locale: "es-MX")
      }.to change(AssistantMessage, :count).by(2)
    end

    it "does NOT increment ai_usage_count for deterministic intents" do
      described_class.call(user: user, message: "¿En qué gasto más?", locale: "es-MX")
      expect(user.quota.reload.ai_usage_count).to eq(0)
    end
  end

  describe "LLM path" do
    let(:fake_text) do
      "Insight: mensaje LLM\n\nAcciones:\n- a\n- b\n\nPróximo paso: revisar."
    end

    before do
      allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
        text: fake_text,
        usage: { prompt_token_count: 800, candidates_token_count: 120, total_token_count: 920 }
      )
    end

    it "calls Ai::Client exactly once and records telemetry" do
      expect_any_instance_of(Ai::Client).to receive(:chat).once.and_return(
        text: fake_text,
        usage: { prompt_token_count: 800, candidates_token_count: 120, total_token_count: 920 }
      )

      result = described_class.call(
        user: user, message: "¿Cómo puedo reducir mi gasto en restaurantes?",
        locale: "es-MX"
      )
      msg = result.payload.assistant_message

      expect(msg.is_deterministic).to be false
      expect(msg.prompt_tokens).to eq(800)
      expect(msg.completion_tokens).to eq(120)
      expect(msg.cost_usd).to be > 0
    end

    it "increments ai_usage_count for LLM calls" do
      described_class.call(
        user: user, message: "¿Cómo puedo reducir mi gasto en restaurantes?",
        locale: "es-MX"
      )
      expect(user.quota.reload.ai_usage_count).to eq(1)
    end
  end

  describe "disclaimer injection" do
    it "returns disclaimer on first turn of a conversation" do
      result = described_class.call(user: user, message: "¿Cuál es mi saldo?", locale: "es-MX")
      expect(result.payload.disclaimer).to be_present
    end

    it "returns nil disclaimer on subsequent turns of the same conversation" do
      first  = described_class.call(user: user, message: "¿Cuál es mi saldo?", locale: "es-MX")
      conv   = first.payload.conversation
      second = described_class.call(user: user, message: "¿En qué gasto más?", locale: "es-MX", conversation: conv)

      expect(second.payload.disclaimer).to be_nil
    end
  end

  describe "quota enforcement" do
    it "raises QuotaExceeded when at the paid limit" do
      Assistant::UsageMeter.new(user).access_result # initialize anchor
      user.quota.update_columns(ai_usage_count: SubscriptionAccess.premium_monthly_ai_calls)

      expect {
        described_class.call(user: user, message: "¿En qué gasto más?", locale: "es-MX")
      }.to raise_error(Assistant::QuotaExceeded)
    end
  end

  describe "locale" do
    it "produces English response when locale is en" do
      result = described_class.call(user: user, message: "where do I spend the most?", locale: "en")
      expect(result.payload.assistant_message.content).to include("Actions:")
      expect(result.payload.assistant_message.content).to include("Next step:")
    end

    it "produces Spanish response when locale is es-MX" do
      result = described_class.call(user: user, message: "¿En qué gasto más?", locale: "es-MX")
      expect(result.payload.assistant_message.content).to include("Acciones:")
      expect(result.payload.assistant_message.content).to include("Próximo paso:")
    end
  end
end
