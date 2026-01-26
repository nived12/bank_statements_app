# spec/services/ai/vision_client_spec.rb
require "rails_helper"
require "webmock/rspec"

RSpec.describe Ai::VisionClient do
  let(:api_key) { "test-api-key" }
  let(:model) { "gemini-2.0-flash-exp" }
  let(:vision_client) { described_class.new(api_key: api_key, model: model) }

  describe "#initialize" do
    context "when API key is missing" do
      it "raises ApiError" do
        expect {
          described_class.new(api_key: nil)
        }.to raise_error(Ai::VisionClient::ApiError, /AI_API_KEY/)
      end
    end

    context "when model is blank" do
      it "uses default model" do
        client = described_class.new(api_key: api_key, model: "")
        expect(client).to be_a(described_class)
      end
    end

    context "with valid configuration" do
      it "initializes successfully" do
        expect(vision_client).to be_a(described_class)
      end
    end
  end

  describe "#analyze_document" do
    let(:image_paths) { [Rails.root.join("spec/fixtures/files/test_page.jpg").to_s] }
    let(:prompt) { "Extract transactions from this statement" }

    before do
      # Create a test image file
      FileUtils.mkdir_p(Rails.root.join("spec/fixtures/files"))
      File.write(image_paths.first, "fake image data") unless File.exist?(image_paths.first)
    end

    context "when image paths are empty" do
      it "raises ArgumentError" do
        expect {
          vision_client.analyze_document([], prompt)
        }.to raise_error(ArgumentError, /Image paths cannot be empty/)
      end
    end

    context "when prompt is empty" do
      it "raises ArgumentError" do
        expect {
          vision_client.analyze_document(image_paths, "")
        }.to raise_error(ArgumentError, /Prompt cannot be empty/)
      end
    end

    context "with successful API response" do
      let(:api_response) do
        {
          "candidates" => [
            {
              "content" => {
                "parts" => [
                  { "text" => '{"transactions": [{"date": "2024-01-15", "amount": 100.0}]}' }
                ]
              }
            }
          ],
          "usageMetadata" => {
            "promptTokenCount" => 100,
            "candidatesTokenCount" => 50,
            "totalTokenCount" => 150
          }
        }.to_json
      end

      it "returns extracted text and usage metadata" do
        stub_request(:post, %r{generativelanguage.googleapis.com})
          .to_return(
            status: 200,
            body: api_response,
            headers: { "Content-Type" => "application/json" }
          )

        result = vision_client.analyze_document(image_paths, prompt)

        expect(result).to be_a(Hash)
        expect(result[:text]).to include("transactions")
        expect(result[:usage]).to include(
          prompt_token_count: 100,
          candidates_token_count: 50,
          total_token_count: 150
        )
      end
    end

    context "when API returns 401 (authentication error)" do
      it "raises ApiError with status code" do
        stub_request(:post, %r{generativelanguage.googleapis.com})
          .to_return(
            status: 401,
            body: '{"error": {"message": "Invalid API key"}}',
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          vision_client.analyze_document(image_paths, prompt)
        }.to raise_error(Ai::VisionClient::ApiError, /401.*Invalid API key/)
      end
    end

    context "when API returns 429 (rate limit)" do
      it "raises ApiError with status code" do
        stub_request(:post, %r{generativelanguage.googleapis.com})
          .to_return(
            status: 429,
            body: '{"error": {"message": "Rate limit exceeded"}}',
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          vision_client.analyze_document(image_paths, prompt)
        }.to raise_error(Ai::VisionClient::ApiError, /429/)
      end
    end

    context "when API returns 500 (server error)" do
      it "raises ApiError with status code" do
        stub_request(:post, %r{generativelanguage.googleapis.com})
          .to_return(
            status: 500,
            body: '{"error": {"message": "Internal server error"}}',
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          vision_client.analyze_document(image_paths, prompt)
        }.to raise_error(Ai::VisionClient::ApiError, /500/)
      end
    end

    context "when response has no text content" do
      let(:empty_response) do
        {
          "candidates" => [
            {
              "content" => {
                "parts" => []
              }
            }
          ]
        }.to_json
      end

      it "raises ApiError" do
        stub_request(:post, %r{generativelanguage.googleapis.com})
          .to_return(
            status: 200,
            body: empty_response,
            headers: { "Content-Type" => "application/json" }
          )

        expect {
          vision_client.analyze_document(image_paths, prompt)
        }.to raise_error(Ai::VisionClient::ApiError, /No text content/)
      end
    end

    context "when request times out" do
      it "raises Timeout::Error" do
        stub_request(:post, %r{generativelanguage.googleapis.com})
          .to_timeout

        expect {
          vision_client.analyze_document(image_paths, prompt)
        }.to raise_error(Timeout::Error)
      end
    end
  end
end
