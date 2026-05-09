# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Parse Voice", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:category) { create(:category, name: "TestShopping", user: user) }

  let(:ai_response) do
    {
      text: {
        amount: 179.0,
        description: "Amazon",
        transaction_type: "variable_expense",
        date: nil,
        category_id: category.id,
        confidence: 0.92
      }.to_json,
      usage: {}
    }
  end

  before do
    category # ensure category exists
    allow_any_instance_of(Ai::Client).to receive(:chat).and_return(ai_response)
  end

  describe "POST /api/v1/transactions/parse_voice" do
    context "with valid text" do
      it "returns parsed transaction fields" do
        post "/api/v1/transactions/parse_voice",
          params: { text: "Gasté 179 en Amazon" },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        data = json["data"]

        expect(data["amount"]).to eq(179.0)
        expect(data["description"]).to eq("Amazon")
        expect(data["transaction_type"]).to eq("variable_expense")
        expect(data["confidence"]).to eq(0.92)
        expect(data["category_suggestion"]["id"]).to eq(category.id)
        expect(data["category_suggestion"]["name"]).to eq("TestShopping")
      end

      it "returns null category_suggestion when AI returns no category" do
        allow_any_instance_of(Ai::Client).to receive(:chat).and_return(
          {
            text: {
              amount: 50.0,
              description: "Unknown",
              transaction_type: "variable_expense",
              date: nil,
              category_id: nil,
              confidence: 0.6
            }.to_json,
            usage: {}
          }
        )

        post "/api/v1/transactions/parse_voice",
          params: { text: "Compré algo" },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"]["category_suggestion"]).to be_nil
      end
    end

    context "with blank text" do
      it "returns 422 VALIDATION_ERROR" do
        post "/api/v1/transactions/parse_voice",
          params: { text: "" },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"]["text"]).to include("can't be blank")
      end
    end

    context "with text exceeding 500 characters" do
      it "returns 422 VALIDATION_ERROR" do
        post "/api/v1/transactions/parse_voice",
          params: { text: "a" * 501 },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
      end
    end

    context "when not authenticated" do
      it "returns 401" do
        post "/api/v1/transactions/parse_voice", params: { text: "test" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
