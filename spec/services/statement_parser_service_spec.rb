# spec/services/statement_parser_service_spec.rb
require "rails_helper"

RSpec.describe StatementParserService do
  let(:user) { double("User", categories: []) }
  let(:bank_account) { double("BankAccount", bank_name: "bbva", account_number: "123456", parsing_strategy: :hybrid) }
  let(:statement) { double("StatementFile", user: user, bank_account: bank_account, ai_enabled?: true) }
  let(:text_data) { { text: "Sample text", text_chunks: [ "Sample text" ] } }
  let(:service) { described_class.new(statement, text_data) }

  describe "#initialize" do
    it "sets up instance variables correctly" do
      expect(service.instance_variable_get(:@statement)).to eq(statement)
      expect(service.instance_variable_get(:@bank_account)).to eq(bank_account)
      expect(service.instance_variable_get(:@text_data)).to eq(text_data)
      expect(service.instance_variable_get(:@ai_enabled)).to be true
      expect(service.instance_variable_get(:@user)).to eq(user)
    end
  end

  describe "#call" do
    context "when AI is disabled" do
      before do
        allow(statement).to receive(:ai_enabled?).and_return(false)
        allow(service).to receive(:parse_with_deterministic_parser).and_return({ "transactions" => [] })
      end

      it "calls parse_with_deterministic_parser" do
        service.call
        expect(service).to have_received(:parse_with_deterministic_parser).with("Sample text")
      end
    end

    context "when AI is enabled" do
      before do
        allow(statement).to receive(:ai_enabled?).and_return(true)
        allow(bank_account).to receive(:parsing_strategy).and_return(:hybrid)
        allow(service).to receive(:parse_hybrid).and_return({ "transactions" => [ { "description" => "Test" } ] })
      end

      it "calls the appropriate parsing strategy" do
        service.call
        expect(service).to have_received(:parse_hybrid).with([ "Sample text" ], "Sample text")
      end

      it "returns success when transactions are found" do
        result = service.call
        expect(result.success?).to be true
      end

      it "returns failure when no transactions are found" do
        allow(service).to receive(:parse_hybrid).and_return({ "transactions" => [] })
        result = service.call
        expect(result.success?).to be false
        expect(service.errors[:base]).to include("No transactions found with hybrid strategy")
      end
    end

    context "when an error occurs" do
      before do
        allow(statement).to receive(:ai_enabled?).and_return(true)
        allow(service).to receive(:parse_hybrid).and_raise(StandardError.new("Test error"))
      end

      it "handles errors gracefully" do
        result = service.call
        expect(result.success?).to be false
        expect(service.errors[:base]).to include("Test error")
      end
    end
  end

  describe "#parse_with_deterministic_parser" do
    let(:parser_result) { double("ParserResult", success?: true, payload: { "transactions" => [] }) }
    let(:parser_class) { double("ParserClass") }

    before do
      allow(bank_account).to receive(:respond_to?).with(:parser_class).and_return(true)
      allow(bank_account).to receive(:parser_class).and_return(parser_class)
      allow(parser_class).to receive(:call).and_return(parser_result)
    end

    it "uses the bank account's parser class" do
      service.parse_with_deterministic_parser("test text")
      expect(parser_class).to have_received(:call).with("test text")
    end

    it "returns the parser payload when successful" do
      result = service.parse_with_deterministic_parser("test text")
      expect(result).to eq({ "extraction_source" => "deterministic_parser", "transactions" => [] })
    end

    it "falls back to generic parser when bank account doesn't have parser_class" do
      allow(bank_account).to receive(:respond_to?).with(:parser_class).and_return(false)
      allow(service).to receive(:parse_with_generic_parser).and_return({ "transactions" => [] })

      result = service.parse_with_deterministic_parser("test text")
      expect(result["transactions"]).to eq([])
    end
  end

  describe "#parse_with_ai" do
    before do
      allow(service).to receive(:ai_api_available?).and_return(true)
      allow(service).to receive(:process_single_chunk).and_return({ "transactions" => [] })
    end

    it "calls process_single_chunk when AI is available and single chunk" do
      service.parse_with_ai([ "chunk1" ], "full text")
      expect(service).to have_received(:process_single_chunk).with("full text")
    end

    it "returns nil when AI is not available" do
      allow(service).to receive(:ai_api_available?).and_return(false)
      result = service.parse_with_ai([ "chunk1" ], "full text")
      expect(result).to be_nil
    end
  end

  describe "#parse_with_ai_enhancement" do
    let(:parser_result) { { "transactions" => [ { "description" => "Test" } ] } }
    let(:ai_result) { { "transactions" => [ { "description" => "Test", "category" => "Test Category" } ] } }

    before do
      allow(service).to receive(:ai_api_available?).and_return(true)
    end

    it "enhances parser results with AI categorization" do
      expect_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(double("Result", success?: true, payload: ai_result))
      result = service.parse_with_ai_enhancement(parser_result)
    end

    it "returns nil when AI is not available" do
      allow(service).to receive(:ai_api_available?).and_return(false)
      result = service.parse_with_ai_enhancement(parser_result)
      expect(result).to be_nil
    end
  end

  describe "#merge_ai_categorization_with_parser_transactions" do
    let(:parser_result) { { "transactions" => [ { "id" => "TX_001", "description" => "Test", "amount" => 100 } ] } }
    let(:ai_result) { { "transactions" => [ { "id" => "TX_001", "description" => "Test", "amount" => 100, "category" => "Test Category" } ] } }

    it "merges AI categorization with parser transactions" do
      result = service.merge_ai_categorization_with_parser_transactions(parser_result, ai_result)

      expect(result["ai_enhancement"]).to be true
      expect(result["transactions"].length).to eq(1)
    end

    it "handles empty AI result gracefully" do
      empty_ai_result = { "transactions" => [] }
      result = service.merge_ai_categorization_with_parser_transactions(parser_result, empty_ai_result)

      expect(result).to eq(parser_result)
    end

    it "returns parser result when AI result is nil" do
      result = service.merge_ai_categorization_with_parser_transactions(parser_result, nil)
      expect(result).to eq(parser_result)
    end
  end

  describe "#merge_transaction_data" do
    let(:parser_txn) { { "id" => "TX_001", "description" => "Test", "amount" => 100 } }
    let(:ai_txn) { { "id" => "TX_001", "category" => "Test Category", "merchant" => "Test Merchant" } }

    it "merges AI data into parser transaction" do
      result = service.send(:merge_transaction_data, parser_txn, ai_txn)

      expect(result["category"]).to eq("Test Category")
      expect(result["merchant"]).to eq("Test Merchant")
      expect(result["description"]).to eq("Test") # Original data preserved
    end

    it "only updates transaction_type if AI provides more specific type" do
      ai_txn["transaction_type"] = "fixed_expense"
      result = service.send(:merge_transaction_data, parser_txn, ai_txn)

      expect(result["transaction_type"]).to eq("fixed_expense")
    end

    it "does not update transaction_type if AI provides generic type" do
      parser_txn["transaction_type"] = "income"
      ai_txn["transaction_type"] = "variable_expense"
      result = service.send(:merge_transaction_data, parser_txn, ai_txn)

      expect(result["transaction_type"]).to eq("income") # Original preserved
    end
  end

  describe "#parse_with_generic_parser" do
    let(:generic_result) { double("GenericResult", success?: true, payload: { "transactions" => [] }) }

    before do
      allow(PdfParser::Generic).to receive(:call).and_return(generic_result)
    end

    it "calls PdfParser::Generic" do
      service.send(:parse_with_generic_parser, "test text")
      expect(PdfParser::Generic).to have_received(:call).with("test text")
    end

    it "returns the payload when successful" do
      result = service.send(:parse_with_generic_parser, "test text")
      expect(result).to eq({ "extraction_source" => "generic_parser", "transactions" => [] })
    end

    it "returns nil when parser fails" do
      allow(generic_result).to receive(:success?).and_return(false)
      allow(generic_result).to receive(:errors).and_return(double("Errors", full_messages: [ "Error message" ]))

      result = service.send(:parse_with_generic_parser, "test text")
      expect(result).to be_nil
    end
  end

  describe "#context_for_logging" do
    before do
      allow(statement).to receive(:id).and_return(123)
      allow(bank_account).to receive(:parser_type).and_return("bbva_savings")
      allow(Current).to receive(:user).and_return(double("CurrentUser", id: 456))
    end

    it "returns logging context" do
      context = service.send(:context_for_logging)

      expect(context[:statement_id]).to eq(123)
      expect(context[:bank_account]).to eq("bbva")
      expect(context[:user_id]).to eq(456)
      expect(context[:parser_type]).to eq("bbva_savings")
    end
  end
end
