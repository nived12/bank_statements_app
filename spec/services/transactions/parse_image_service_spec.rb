# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transactions::ParseImageService do
  let(:user) { create(:user) }
  let(:category) { create(:category, name: "TestGrocery", user: user) }
  let(:vision_client) { instance_double(Ai::VisionClient) }

  # A minimal 1x1 white PNG in base64
  let(:tiny_png_base64) do
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg=="
  end

  let(:ai_success_response) do
    {
      text: {
        amount: 342.5,
        description: "Walmart Supercenter",
        merchant_name: "Walmart Supercenter",
        transaction_type: "variable_expense",
        date: "2026-03-10",
        category_id: category.id,
        bank_account_id: nil,
        items: [],
        confidence: 0.88
      }.to_json,
      usage: {}
    }
  end

  before do
    category
    allow(vision_client).to receive(:analyze_document).and_return(ai_success_response)
  end

  describe "#call" do
    it "returns a success result with parsed fields including category and date" do
      result = described_class.call(
        image_base64: tiny_png_base64,
        mime_type: "image/png",
        user: user,
        vision_client: vision_client
      )

      expect(result).to be_success
      payload = result.payload
      expect(payload[:amount]).to eq(342.5)
      expect(payload[:description]).to eq("Walmart Supercenter")
      expect(payload[:transaction_type]).to eq("variable_expense")
      expect(payload[:confidence]).to eq(0.88)
      expect(payload[:date]).to eq("2026-03-10")
      expect(payload[:category_suggestion][:id]).to eq(category.id)
      expect(payload[:category_suggestion][:name]).to eq("TestGrocery")
    end

    it "returns nil category_suggestion when AI returns unknown category_id" do
      allow(vision_client).to receive(:analyze_document).and_return(
        {
          text: {
            amount: 100.0,
            description: "Store",
            transaction_type: "variable_expense",
            date: nil,
            category_id: 999_999,
            confidence: 0.7
          }.to_json,
          usage: {}
        }
      )

      result = described_class.call(
        image_base64: tiny_png_base64,
        mime_type: "image/png",
        user: user,
        vision_client: vision_client
      )
      expect(result).to be_success
      expect(result.payload[:category_suggestion]).to be_nil
    end

    it "returns nil date when not found in receipt" do
      allow(vision_client).to receive(:analyze_document).and_return(
        {
          text: {
            amount: 100.0,
            description: "Store",
            transaction_type: "variable_expense",
            date: nil,
            category_id: nil,
            confidence: 0.7
          }.to_json,
          usage: {}
        }
      )

      result = described_class.call(
        image_base64: tiny_png_base64,
        mime_type: "image/png",
        user: user,
        vision_client: vision_client
      )
      expect(result).to be_success
      expect(result.payload[:date]).to be_nil
    end

    it "cleans up the tempfile after use" do
      tempfile_path = nil
      allow(vision_client).to receive(:analyze_document) do |paths, _prompt|
        tempfile_path = paths.first
        ai_success_response
      end

      described_class.call(
        image_base64: tiny_png_base64,
        mime_type: "image/png",
        user: user,
        vision_client: vision_client
      )

      expect(File.exist?(tempfile_path)).to be(false)
    end

    it "returns failure when AI response is invalid JSON" do
      allow(vision_client).to receive(:analyze_document).and_return(
        { text: "not json", usage: {} }
      )

      result = described_class.call(
        image_base64: tiny_png_base64,
        mime_type: "image/png",
        user: user,
        vision_client: vision_client
      )
      expect(result).to be_failure
    end

    it "returns failure when AI client raises an error" do
      allow(vision_client).to receive(:analyze_document)
        .and_raise(Ai::VisionClient::ApiError, "Gemini API error")

      result = described_class.call(
        image_base64: tiny_png_base64,
        mime_type: "image/png",
        user: user,
        vision_client: vision_client
      )
      expect(result).to be_failure
    end

    it "uses .jpg extension for image/jpeg" do
      captured_path = nil
      allow(vision_client).to receive(:analyze_document) do |paths, _prompt|
        captured_path = paths.first
        ai_success_response
      end

      described_class.call(
        image_base64: tiny_png_base64,
        mime_type: "image/jpeg",
        user: user,
        vision_client: vision_client
      )
      expect(captured_path).to match(/\.jpg\z/)
    end

    context "with merchant, bank_account_id, and items" do
      it "returns merchant, bank_account_id, items, and concept from receipt" do
        allow(vision_client).to receive(:analyze_document).and_return(
          {
            text: {
              amount: 127.5,
              description: "Oxxo",
              merchant_name: "Oxxo",
              transaction_type: "variable_expense",
              date: nil,
              category_id: nil,
              bank_account_id: nil,
              items: [
                { "name" => "Galletas Marías", "amount" => 25.0 },
                { "name" => "Refresco", "amount" => 18.5 }
              ],
              confidence: 0.91
            }.to_json,
            usage: {}
          }
        )

        result = described_class.call(
          image_base64: tiny_png_base64,
          mime_type: "image/png",
          user: user,
          vision_client: vision_client
        )

        expect(result).to be_success
        expect(result.payload[:merchant]).to eq("Oxxo")
        expect(result.payload[:bank_account_id]).to be_nil
        expect(result.payload[:items]).to eq([
          { name: "Galletas Marías", amount: 25.0 },
          { name: "Refresco", amount: 18.5 }
        ])
        expect(result.payload[:concept]).to include("Galletas Marías $25.00")
        expect(result.payload[:concept]).to include("Refresco $18.50")
      end

      it "returns empty items and nil concept when receipt has no line items" do
        result = described_class.call(
          image_base64: tiny_png_base64,
          mime_type: "image/png",
          user: user,
          vision_client: vision_client
        )

        expect(result).to be_success
        expect(result.payload[:items]).to eq([])
        expect(result.payload[:concept]).to be_nil
      end

      it "nullifies bank_account_id when AI returns id not belonging to the user" do
        allow(vision_client).to receive(:analyze_document).and_return(
          {
            text: {
              amount: 50.0,
              description: "Store",
              merchant_name: nil,
              transaction_type: "variable_expense",
              date: nil,
              category_id: nil,
              bank_account_id: 999_999,
              items: [],
              confidence: 0.7
            }.to_json,
            usage: {}
          }
        )

        result = described_class.call(
          image_base64: tiny_png_base64,
          mime_type: "image/png",
          user: user,
          vision_client: vision_client
        )

        expect(result).to be_success
        expect(result.payload[:bank_account_id]).to be_nil
      end
    end
  end
end
