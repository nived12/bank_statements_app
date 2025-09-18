# spec/services/ai/post_processor_spec.rb
require "rails_helper"

RSpec.describe Ai::PostProcessor do
  let(:client) { instance_double(Ai::Client) }

  let(:post_processor) do
    described_class.new(
      raw_text: raw_text,
      bank_name: bank_name,
      account_number: account_number,
      categories: categories,
      client: client
    )
  end

  let(:bank_name) { "BBVA" }
  let(:account_number) { "1234567890" }
  let(:user) { create(:user) }
  let(:categories) { Category.where(user: user) }

  before do
    # Create some categories for the user
    create(:category, user: user, name: "Ingresos", parent_id: nil)
    create(:category, user: user, name: "Servicios", parent_id: nil)
  end

  describe "#call" do
    context "when processing parsed transactions (hybrid mode)" do
      let(:raw_text) { "SPEI ENVIADO 1000.00\nDEPOSITO NOMINA 5000.00" }
      let(:success_response) { double("Response", success?: true, payload: { "transactions" => [] }) }
      let(:essential_text_response) { double("Response", success?: true, payload: "SPEI ENVIADO 1000.00\nDEPOSITO NOMINA 5000.00") }
      let(:prompt_response) { double("Response", success?: true, payload: "prompt") }

      before do
        # TextAnalysis is now a concern, so we don't need to mock it
        # PromptBuilder is now a concern, so we don't need to mock it
        allow(client).to receive(:chat).and_return('{"transactions": []}')
        # ResponseParser is now a concern, so we don't need to mock it
      end

      it "processes in hybrid enhancement mode" do
        result = post_processor.call

        expect(result.success?).to be true
        expect(result.payload).to eq({ "transactions" => [], "extraction_source" => "ai_enhanced_parser" })
        # TextAnalysis is now a concern, so we don't need to verify its calls
        # PromptBuilder is now a concern, so we don't need to verify its calls
        expect(client).to have_received(:chat)
        # ResponseParser is now a concern, so we don't need to verify its calls
      end
    end

    context "when processing raw text (fallback mode)" do
      let(:raw_text) { "SPEI ENVIADO\nDEPOSITO NOMINA" }

      before do
        # Mock the parsed_transactions? method to return false so it goes to fallback mode
        allow_any_instance_of(described_class).to receive(:parsed_transactions?).and_return(
          double("Response", success?: true, payload: false)
        )
        allow(client).to receive(:chat).and_return('{"transactions": []}')
      end

      it "processes in fallback parsing mode" do
        result = post_processor.call

        expect(result.success?).to be true
        expect(result.payload).to eq({ "transactions" => [], "extraction_source" => "ai_parser_fallback" })
        expect(client).to have_received(:chat)
      end
    end

    context "when an error occurs" do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error and returns failure response" do
        # Test with invalid input that will cause an error
        error_processor = described_class.new(
          raw_text: nil,  # This will cause an error in TextAnalysis
          bank_name: "Test Bank",
          account_number: "1234567890",
          categories: [],
          client: client
        )
        result = error_processor.call

        expect(result).not_to be_success
        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end
  end
end
