# spec/services/ai/post_processor_spec.rb
require "rails_helper"

RSpec.describe Ai::PostProcessor do
  let(:client) { instance_double(Ai::Client) }
  let(:validator) { instance_double(Ai::TransactionValidator) }
  let(:text_processor) { instance_double(Ai::TextProcessor) }
  let(:prompt_builder) { instance_double(Ai::PromptBuilder) }
  let(:response_parser) { instance_double(Ai::ResponseParser) }

  let(:post_processor) do
    described_class.new(client: client).tap do |pp|
      pp.instance_variable_set(:@validator, validator)
      pp.instance_variable_set(:@text_processor, text_processor)
      pp.instance_variable_set(:@prompt_builder, prompt_builder)
      pp.instance_variable_set(:@response_parser, response_parser)
    end
  end

  let(:raw_text) { "SPEI ENVIADO\nDEPOSITO NOMINA" }
  let(:bank_name) { "BBVA" }
  let(:account_number) { "1234567890" }
  let(:categories) { [ double("Category", name: "Servicios", id: 1) ] }

  describe "#call" do
    context "when processing parsed transactions (hybrid mode)" do
      let(:success_response) { double("Response", success?: true, payload: { "transactions" => [] }) }
      let(:essential_text_response) { double("Response", success?: true, payload: "SPEI ENVIADO\nDEPOSITO NOMINA") }
      let(:prompt_response) { double("Response", success?: true, payload: "prompt") }

      before do
        allow(text_processor).to receive(:parsed_transactions?).with(raw_text).and_return(success_response)
        allow(text_processor).to receive(:extract_keywords_inline).with(raw_text).and_return(essential_text_response)
        allow(prompt_builder).to receive(:build_categorization_prompt).and_return(prompt_response)
        allow(client).to receive(:chat).with("prompt").and_return('{"transactions": []}')
        allow(response_parser).to receive(:parse).with('{"transactions": []}', "ai_enhanced_parser").and_return(success_response)
      end

      it "processes in hybrid enhancement mode" do
        result = post_processor.call(
          raw_text: raw_text,
          bank_name: bank_name,
          account_number: account_number,
          categories: categories
        )

        expect(result.success?).to be true
        expect(result.payload).to eq({ "transactions" => [] })
        expect(text_processor).to have_received(:parsed_transactions?).with(raw_text)
        expect(text_processor).to have_received(:extract_keywords_inline).with(raw_text)
        expect(prompt_builder).to have_received(:build_categorization_prompt).with("SPEI ENVIADO\nDEPOSITO NOMINA", categories)
        expect(client).to have_received(:chat).with("prompt")
        expect(response_parser).to have_received(:parse).with('{"transactions": []}', "ai_enhanced_parser")
      end
    end

    context "when processing raw text (fallback mode)" do
      let(:prompt_builder_instance) { instance_double(Ai::PromptBuilders::StatementToJson) }
      let(:not_parsed_response) { double("Response", success?: true, payload: false) }
      let(:success_response) { double("Response", success?: true, payload: { "transactions" => [] }) }

      before do
        allow(text_processor).to receive(:parsed_transactions?).with(raw_text).and_return(not_parsed_response)
        allow(Ai::PromptBuilders::StatementToJson).to receive(:new).and_return(prompt_builder_instance)
        allow(prompt_builder_instance).to receive(:build).and_return("fallback_prompt")
        allow(client).to receive(:chat).with("fallback_prompt").and_return('{"transactions": []}')
        allow(response_parser).to receive(:parse).with('{"transactions": []}', "ai_parser_fallback").and_return(success_response)
      end

      it "processes in fallback parsing mode" do
        result = post_processor.call(
          raw_text: raw_text,
          bank_name: bank_name,
          account_number: account_number,
          categories: categories
        )

        expect(result.success?).to be true
        expect(result.payload).to eq({ "transactions" => [] })
        expect(text_processor).to have_received(:parsed_transactions?).with(raw_text)
        expect(Ai::PromptBuilders::StatementToJson).to have_received(:new).with(
          bank_name: bank_name,
          account_number: account_number,
          categories: categories
        )
        expect(prompt_builder_instance).to have_received(:build).with(raw_text: raw_text)
        expect(client).to have_received(:chat).with("fallback_prompt")
        expect(response_parser).to have_received(:parse).with('{"transactions": []}', "ai_parser_fallback")
      end
    end

    context "when an error occurs" do
      before do
        allow(text_processor).to receive(:parsed_transactions?).and_raise(StandardError, "Test error")
        allow(Rails.logger).to receive(:error)
      end

      it "logs the error and returns failure response" do
        allow(Rails.logger).to receive(:error)

        result = post_processor.call(
          raw_text: "test text",
          bank_name: "Test Bank",
          account_number: "1234567890",
          categories: []
        )

        expect(result).not_to be_success
        expect(Rails.logger).to have_received(:error).with("Ai::PostProcessor failed with 1 error(s):")
        expect(Rails.logger).to have_received(:error).with("base: AI processing failed: Test error")
      end
    end

    context "when text processor fails" do
      let(:failure_response) { double("Response", success?: false, payload: nil) }

      before do
        allow(text_processor).to receive(:parsed_transactions?).with(raw_text).and_return(failure_response)
      end

      it "returns failure response" do
        result = post_processor.call(
          raw_text: raw_text,
          bank_name: bank_name,
          account_number: account_number,
          categories: categories
        )

        expect(result.success?).to be false
      end
    end
  end
end
