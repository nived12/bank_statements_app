# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Assistant::Chats", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
  end

  def make_paid!
    user.update_columns(trial_ends_at: nil)
    customer = create(:pay_customer, owner: user)
    create(:pay_subscription, customer: customer, status: "active")
  end

  describe "POST /api/v1/assistant/chat" do
    context "when unauthenticated" do
      it "returns 401" do
        post "/api/v1/assistant/chat", params: { message: "hola" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user is non-subscriber and trial expired" do
      before { user.update_columns(trial_ends_at: 1.day.ago) }

      it "returns 402 SUBSCRIPTION_REQUIRED" do
        post "/api/v1/assistant/chat",
          params: { message: "¿En qué gasto más?", locale: "es-MX" },
          headers: auth_headers

        expect(response).to have_http_status(:payment_required)
        expect(JSON.parse(response.body)["error"]["code"]).to eq("SUBSCRIPTION_REQUIRED")
      end
    end

    context "when trial user hits the shared-pool cap" do
      before do
        user.update_columns(
          trial_ends_at: 7.days.from_now,
          ai_usage_count: SubscriptionAccess.free_tier_ai_calls
        )
      end

      it "returns 402 AI_LIMIT_REACHED" do
        post "/api/v1/assistant/chat",
          params: { message: "¿En qué gasto más?", locale: "es-MX" },
          headers: auth_headers

        expect(response).to have_http_status(:payment_required)
        expect(JSON.parse(response.body)["error"]["code"]).to eq("AI_LIMIT_REACHED")
      end
    end

    context "when paid user hits the 100-message monthly cap" do
      before do
        make_paid!
        Assistant::UsageMeter.new(user).access_result # initialize anchor
        user.update_columns(assistant_messages_this_month: 100)
      end

      it "returns 402 ASSISTANT_LIMIT_REACHED" do
        post "/api/v1/assistant/chat",
          params: { message: "¿En qué gasto más?", locale: "es-MX" },
          headers: auth_headers

        expect(response).to have_http_status(:payment_required)
        expect(JSON.parse(response.body)["error"]["code"]).to eq("ASSISTANT_LIMIT_REACHED")
      end
    end

    context "with deterministic intent (paid user)" do
      before { make_paid! }

      it "does NOT call Ai::Client and returns is_deterministic: true" do
        expect_any_instance_of(Ai::Client).not_to receive(:chat)

        post "/api/v1/assistant/chat",
          params: { message: "¿En qué gasto más?", locale: "es-MX" },
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["assistant_message"]["is_deterministic"]).to be true
        expect(body["data"]["assistant_message"]["intent"]).to eq("top_categories")
        expect(body["data"]["disclaimer"]).to be_present
        expect(body["meta"]["usage"]["limit"]).to eq(100)
        expect(body["meta"]["usage"]["used"]).to eq(0)
        expect(user.reload.assistant_messages_this_month).to eq(0)
      end
    end

    context "with LLM intent (paid user)" do
      before do
        make_paid!
        allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
          text: "Insight\n\nAcciones:\n- a\n\nPróximo paso: x.",
          usage: { prompt_token_count: 500, candidates_token_count: 100, total_token_count: 600 }
        )
      end

      it "calls Ai::Client exactly once and returns is_deterministic: false" do
        expect_any_instance_of(Ai::Client).to receive(:chat).once.and_return(
          text: "Insight\n\nAcciones:\n- a\n\nPróximo paso: x.",
          usage: { prompt_token_count: 500, candidates_token_count: 100, total_token_count: 600 }
        )

        post "/api/v1/assistant/chat",
          params: { message: "¿Cómo puedo reducir mi gasto en restaurantes?", locale: "es-MX" },
          headers: auth_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]["assistant_message"]["is_deterministic"]).to be false
        expect(body["meta"]["usage"]["used"]).to eq(1)
        expect(user.reload.assistant_messages_this_month).to eq(1)
      end

      it "surfaces threshold_crossed=80 when the LLM call brings the user to 80%" do
        Assistant::UsageMeter.new(user).access_result
        user.update_columns(assistant_messages_this_month: 79, assistant_threshold_shown: 0)

        post "/api/v1/assistant/chat",
          params: { message: "¿Cómo puedo reducir mi gasto en restaurantes?", locale: "es-MX" },
          headers: auth_headers

        body = JSON.parse(response.body)
        expect(body["meta"]["usage"]["threshold_crossed"]).to eq(80)
      end
    end

    context "disclaimer behavior" do
      before { make_paid! }

      it "returns disclaimer on first turn, nil on subsequent turns of same conversation" do
        post "/api/v1/assistant/chat",
          params: { message: "¿Cuál es mi saldo?", locale: "es-MX" },
          headers: auth_headers

        body1 = JSON.parse(response.body)
        expect(body1["data"]["disclaimer"]).to be_present
        conv_id = body1["data"]["conversation"]["id"]

        post "/api/v1/assistant/chat",
          params: { message: "¿En qué gasto más?", conversation_id: conv_id, locale: "es-MX" },
          headers: auth_headers

        body2 = JSON.parse(response.body)
        expect(body2["data"]["disclaimer"]).to be_nil
        expect(body2["data"]["conversation"]["id"]).to eq(conv_id)
      end
    end

    context "locale" do
      before { make_paid! }

      it "returns Spanish content when locale is es-MX" do
        post "/api/v1/assistant/chat",
          params: { message: "¿En qué gasto más?", locale: "es-MX" },
          headers: auth_headers

        body = JSON.parse(response.body)
        expect(body["data"]["assistant_message"]["content"]).to include("Acciones:")
      end

      it "returns English content when locale is en" do
        post "/api/v1/assistant/chat",
          params: { message: "where do I spend the most?", locale: "en" },
          headers: auth_headers

        body = JSON.parse(response.body)
        expect(body["data"]["assistant_message"]["content"]).to include("Actions:")
      end
    end

    context "validation" do
      before { make_paid! }

      it "returns 422 when message is blank" do
        post "/api/v1/assistant/chat",
          params: { message: "" },
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "returns 422 when message exceeds 2000 chars" do
        post "/api/v1/assistant/chat",
          params: { message: "a" * 2_001 },
          headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
