# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Assistant::Conversations", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" }
  end

  def make_paid!(target = user)
    target.update_columns(trial_ends_at: nil)
    customer = create(:pay_customer, owner: target)
    create(:pay_subscription, customer: customer, status: "active")
  end

  before { make_paid! }

  describe "GET /api/v1/assistant/conversations" do
    it "returns the current user's conversations" do
      mine  = user.assistant_conversations.create!(locale: "es-MX", title: "Mine",  last_message_at: 1.hour.ago)
      _other = other_user.assistant_conversations.create!(locale: "es-MX", title: "Other", last_message_at: 1.hour.ago)

      get "/api/v1/assistant/conversations", headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)["data"]["conversations"].map { |c| c["id"] }
      expect(ids).to eq([mine.id])
    end

    it "returns 401 when unauthenticated" do
      get "/api/v1/assistant/conversations"
      expect(response).to have_http_status(:unauthorized)
    end

    it "paginates" do
      12.times do |i|
        user.assistant_conversations.create!(locale: "es-MX", title: "T#{i}", last_message_at: i.hours.ago)
      end

      get "/api/v1/assistant/conversations", params: { page_size: 5, page: 1 }, headers: auth_headers

      body = JSON.parse(response.body)
      expect(body["data"]["conversations"].size).to eq(5)
      expect(body["meta"]["pagination"]["pages"]).to be >= 2
    end
  end

  describe "GET /api/v1/assistant/conversations/:id" do
    it "returns the conversation with messages" do
      conv = user.assistant_conversations.create!(locale: "es-MX", title: "T")
      conv.messages.create!(user: user, role: "user", content: "hi")
      conv.messages.create!(user: user, role: "assistant", content: "hello")

      get "/api/v1/assistant/conversations/#{conv.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["messages"].size).to eq(2)
    end

    it "404s on someone else's conversation" do
      conv = other_user.assistant_conversations.create!(locale: "es-MX", title: "X")

      get "/api/v1/assistant/conversations/#{conv.id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/assistant/conversations/:id" do
    it "soft-deletes the conversation and hides it from the index" do
      conv = user.assistant_conversations.create!(locale: "es-MX")
      conv.messages.create!(user: user, role: "user", content: "x")

      expect {
        delete "/api/v1/assistant/conversations/#{conv.id}", headers: auth_headers
      }.not_to change(AssistantConversation, :count)

      expect(response).to have_http_status(:ok)
      expect(conv.reload.discarded?).to be(true)
      expect(AssistantMessage.where(assistant_conversation_id: conv.id).count).to eq(1)

      get "/api/v1/assistant/conversations", headers: auth_headers
      ids = JSON.parse(response.body).dig("data", "conversations").map { |c| c["id"] }
      expect(ids).not_to include(conv.id.to_s)
    end

    it "404s when trying to delete an already-discarded conversation" do
      conv = user.assistant_conversations.create!(locale: "es-MX")
      conv.discard!

      delete "/api/v1/assistant/conversations/#{conv.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
