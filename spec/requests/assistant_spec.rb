# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Assistant web", type: :request do
  let(:user) { create(:user) }

  describe "GET /assistant" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get assistant_path
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when authenticated without subscription" do
      before do
        sign_in_user(user)
        user.update_columns(trial_ends_at: nil)
        allow_any_instance_of(AssistantController).to receive(:check_legal_consent!)
      end

      it "redirects to pricing" do
        get assistant_path
        expect(response).to redirect_to(pricing_path)
      end
    end

    context "when authenticated with active trial" do
      before do
        sign_in_user(user)
        user.update_columns(trial_ends_at: 7.days.from_now)
        allow_any_instance_of(AssistantController).to receive(:check_legal_consent!)
        allow_any_instance_of(User).to receive(:assistant_access_result).and_return({ allowed: true })
      end

      it "renders the assistant chat UI" do
        get assistant_path
        expect(response).to have_http_status(:ok)
      end

      it "shows the assistant header" do
        get assistant_path
        expect(response.body).to include("Vittbot")
      end

      it "renders the compact frame when ?layout=compact" do
        get assistant_path, params: { layout: "compact" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="vittbot_fab_frame"')
        # No left-rail history shows in compact frame
        expect(response.body).not_to include("assistant.history.title")
      end

      it "starts a fresh conversation when ?new=1, ignoring prior history" do
        existing = create(:assistant_conversation, user: user, title: "Previous chat")
        create(
          :assistant_message, assistant_conversation: existing, user: user,
          role: "user", content: "earlier question"
        )

        get assistant_path, params: { new: 1 }
        expect(response).to have_http_status(:ok)
        # Prior content must not bleed into the new empty-state view
        expect(response.body).not_to include("earlier question")
      end
    end
  end

  describe "POST /assistant/messages" do
    let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

    before do
      sign_in_user(user)
      user.update_columns(trial_ends_at: 7.days.from_now)
      allow_any_instance_of(AssistantController).to receive(:check_legal_consent!)
      allow_any_instance_of(User).to receive(:assistant_access_result).and_return({ allowed: true })
    end

    context "with blank message" do
      it "returns a turbo stream error" do
        post messages_assistant_path,
          params: { content: "" },
          headers: turbo_headers
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end

    context "with valid message" do
      let(:chat_result) do
        double(
          "Result",
          success?: true,
          payload: OpenStruct.new(
            conversation: create(:assistant_conversation, user: user),
            user_message: create(:assistant_message, user: user, role: "user", content: "test"),
            assistant_message: create(:assistant_message, user: user, role: "assistant", content: "response"),
            disclaimer: nil,
            usage: { used: 1, limit: 100, remaining: 99, resets_at: 1.month.from_now }
          )
        )
      end

      before { allow(Assistant::ChatService).to receive(:call).and_return(chat_result) }

      it "returns a turbo stream response" do
        post messages_assistant_path,
          params: { content: "¿cuánto gasté este mes?" },
          headers: turbo_headers
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "calls ChatService with the message" do
        expect(Assistant::ChatService).to receive(:call).with(
          hash_including(message: "¿cuánto gasté este mes?")
        ).and_return(chat_result)
        post messages_assistant_path,
          params: { content: "¿cuánto gasté este mes?" },
          headers: turbo_headers
      end
    end

    context "when quota exceeded" do
      before do
        allow(Assistant::ChatService).to receive(:call).and_raise(Assistant::QuotaExceeded.new("Limit reached"))
      end

      it "returns a turbo stream with quota error" do
        post messages_assistant_path,
          params: { content: "hello" },
          headers: turbo_headers
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response).to have_http_status(:payment_required)
      end
    end
  end
end
