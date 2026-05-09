# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Transactions - Parse Image", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:category) { create(:category, name: "TestGrocery", user: user) }
  let(:vision_client) { instance_double(Ai::VisionClient) }

  # A minimal 1x1 white PNG in base64
  let(:tiny_png_base64) do
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg=="
  end

  let(:ai_response) do
    {
      text: {
        amount: 342.5,
        description: "Walmart Supercenter",
        transaction_type: "variable_expense",
        date: "2026-03-10",
        category_id: category.id,
        confidence: 0.88
      }.to_json,
      usage: {}
    }
  end

  before do
    category # ensure category exists
    allow(Ai::VisionClient).to receive(:new).and_return(vision_client)
    allow(vision_client).to receive(:analyze_document).and_return(ai_response)
  end

  describe "POST /api/v1/transactions/parse_image" do
    context "with valid image" do
      it "returns parsed transaction fields" do
        post "/api/v1/transactions/parse_image",
          params: { image: tiny_png_base64, mime_type: "image/png" },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        data = json["data"]

        expect(data["amount"]).to eq(342.5)
        expect(data["description"]).to eq("Walmart Supercenter")
        expect(data["transaction_type"]).to eq("variable_expense")
        expect(data["confidence"]).to eq(0.88)
        expect(data["category_suggestion"]["id"]).to eq(category.id)
        expect(data["category_suggestion"]["name"]).to eq("TestGrocery")
      end

      it "supports image/jpeg mime type" do
        post "/api/v1/transactions/parse_image",
          params: { image: tiny_png_base64, mime_type: "image/jpeg" },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context "with unsupported mime type" do
      it "returns 422 UNSUPPORTED_MIME_TYPE" do
        post "/api/v1/transactions/parse_image",
          params: { image: tiny_png_base64, mime_type: "image/gif" },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("UNSUPPORTED_MIME_TYPE")
        expect(json["error"]["details"]["supported"]).to include("image/jpeg", "image/png", "image/webp")
      end
    end

    context "with blank image" do
      it "returns 422 VALIDATION_ERROR" do
        post "/api/v1/transactions/parse_image",
          params: { image: "", mime_type: "image/jpeg" },
          headers: auth_headers,
          as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("VALIDATION_ERROR")
        expect(json["error"]["details"]["image"]).to include("can't be blank")
      end
    end

    context "when Content-Length exceeds 6.7MB" do
      it "returns 422 IMAGE_TOO_LARGE without calling AI" do
        expect(Ai::VisionClient).not_to receive(:new)

        post "/api/v1/transactions/parse_image",
          params: { image: tiny_png_base64, mime_type: "image/jpeg" },
          headers: auth_headers.merge("Content-Length" => "7000001"),
          as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]["code"]).to eq("IMAGE_TOO_LARGE")
      end
    end

    context "when not authenticated" do
      it "returns 401" do
        post "/api/v1/transactions/parse_image",
          params: { image: tiny_png_base64, mime_type: "image/jpeg" },
          as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
