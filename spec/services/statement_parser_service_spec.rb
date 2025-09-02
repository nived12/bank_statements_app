require "rails_helper"

RSpec.describe StatementParserService do
  include_context "with current user"

  let(:statement) { double("StatementFile") }
  let(:bank_account) { double("BankAccount", account_type: "credit") }
  let(:text_data) { { text_chunks: [ "chunk1", "chunk2" ], text: "raw text" } }
  let(:service) { described_class.new(statement, text_data) }

  # Helper method to create mock ApplicationService::Response objects
  def mock_response(success:, payload:)
    double("Response", success?: success, payload: payload)
  end

  before do
    allow(statement).to receive(:bank_account).and_return(bank_account)
    allow(statement).to receive(:ai_enabled?).and_return(true)
    allow(bank_account).to receive(:bank_name).and_return("BBVA")
    allow(bank_account).to receive(:account_number).and_return("1234")
    # Mock the concern methods directly on the service
    allow(service).to receive(:ai_api_available?).and_return(true)
    allow(service).to receive(:ai_max_retries).and_return(3)
    allow(service).to receive(:ai_retry_delay_base).and_return(2)
    allow(service).to receive(:sleep) # Stub sleep to avoid delays in tests
  end

  describe "#call" do
    before do
      allow(bank_account).to receive(:parsing_strategy).and_return(:hybrid)
      allow(service).to receive(:parse_hybrid).and_return({ "transactions" => [] })
    end

    it "calls hybrid approach when strategy is hybrid" do
      service.call

      expect(service).to have_received(:parse_hybrid)
        .with(text_data[:text_chunks], text_data[:text])
    end
  end

  describe "#parse_hybrid" do
    let(:parser_result) { { "transactions" => [ { "id" => 1 } ] } }
    let(:ai_result) { { "transactions" => [ { "id" => 1, "category" => "food" } ] } }

    before do
      allow(service).to receive(:parse_with_deterministic_parser).and_return(parser_result)
      allow(service).to receive(:parse_with_ai_enhancement).and_return(ai_result)
      allow(service).to receive(:merge_ai_categorization_with_parser_transactions)
        .and_return({ "transactions" => [] })
    end

    context "when parser succeeds and AI succeeds" do
      it "merges results and sets extraction source" do
        result = service.send(:parse_hybrid, text_data[:text_chunks], text_data[:text])

        expect(service).to have_received(:merge_ai_categorization_with_parser_transactions)
          .with(parser_result, ai_result)
      end
    end

    context "when parser succeeds but AI fails" do
      before do
        allow(service).to receive(:parse_with_ai_enhancement).and_return(nil)
      end

      it "uses parser result with basic categorization" do
        result = service.send(:parse_hybrid, text_data[:text_chunks], text_data[:text])

        expect(result).to eq(parser_result)
        expect(result["extraction_source"]).to eq("parser_with_basic_categorization")
      end
    end

    context "when parser fails completely" do
      before do
        allow(service).to receive(:parse_with_deterministic_parser).and_return(nil)
        allow(service).to receive(:parse_with_ai).and_return(ai_result)
      end

      it "falls back to AI for full parsing" do
        result = service.send(:parse_hybrid, text_data[:text_chunks], text_data[:text])

        expect(service).to have_received(:parse_with_ai).with(text_data[:text_chunks], text_data[:text])
        expect(result).to eq(ai_result)
        expect(result["extraction_source"]).to eq("ai_parser_fallback")
      end
    end
  end

  describe "#parse_with_ai_enhancement" do
    let(:parser_result) { { "transactions" => Array.new(10) { |i| { "description" => "Transaction #{i + 1}" } } } }
    let(:user_categories) do
      [
        double("category1", id: 1, name: "Test", children: []),
        double("category2", id: 2, name: "Other", children: [])
      ]
    end
    let(:post_processor) { instance_double(Ai::PostProcessor) }

    before do
      allow(Current.user).to receive(:categories).and_return(user_categories)
      allow(service).to receive(:ai_api_available?).and_return(true)
      allow(Ai::PostProcessor).to receive(:new).and_return(post_processor)
    end

    context "when single batch succeeds" do
      let(:ai_result) { mock_response(success: true, payload: { "transactions" => Array.new(10) { |i| { "description" => "Transaction #{i + 1}", "category" => "Test" } } }) }

      before do
        allow(post_processor).to receive(:call).and_return(ai_result)
      end

      it "returns AI result without batching" do
        result = service.send(:parse_with_ai_enhancement, parser_result)

        # Now processes each transaction individually: 10 calls for 10 transactions
        expect(post_processor).to have_received(:call).exactly(10).times
        # Result now includes extraction_source, and should have 10 transactions
        expect(result["transactions"].count).to eq(10)
        expect(result["extraction_source"]).to eq("ai_enhanced_parser")
        # Each transaction should have the expected structure
        expect(result["transactions"].first["category"]).to eq("Test")
        expect(result["transactions"].first["description"]).to eq("Transaction 1")
      end
    end

    context "when all batching strategies fail" do
      let(:ai_result) { mock_response(success: false, payload: nil) }

      before do
        allow(post_processor).to receive(:call).and_return(ai_result)
      end

      it "returns nil after trying all strategies" do
        result = service.send(:parse_with_ai_enhancement, parser_result)

        # Should have called AI multiple times trying different strategies
        expect(post_processor).to have_received(:call).at_least(:once)
        expect(result).to be_nil
      end
    end

    context "when AI API is not available" do
      before do
        allow(service).to receive(:ai_api_available?).and_return(false)
      end

      it "returns nil immediately" do
        result = service.send(:parse_with_ai_enhancement, parser_result)

        expect(result).to be_nil
      end
    end
  end

  describe "#create_transaction_batches" do
    let(:transaction_descriptions) { Array.new(10) { |i| "Transaction #{i + 1}" } }

    context "with 1 batch" do
      it "creates 1 batch with all transactions" do
        batches = service.send(:create_transaction_batches, transaction_descriptions, 1)

        expect(batches.count).to eq(1)
        expect(batches.first.count).to eq(10)
      end
    end

    context "with 2 batches" do
      it "creates 2 batches with balanced distribution" do
        batches = service.send(:create_transaction_batches, transaction_descriptions, 2)

        expect(batches.count).to eq(2)
        expect(batches.first.count).to eq(5)
        expect(batches.last.count).to eq(5)
      end
    end

    context "with 4 batches" do
      it "creates 4 batches with balanced distribution" do
        batches = service.send(:create_transaction_batches, transaction_descriptions, 4)

        expect(batches.count).to eq(4)
        expect(batches.map(&:count)).to eq([ 3, 3, 3, 1 ])
      end
    end
  end

  describe "#process_ai_enhancement_batches" do
    let(:batches) do
      [
        [ "Transaction 1", "Transaction 2" ],
        [ "Transaction 3", "Transaction 4" ]
      ]
    end
    let(:user_categories) do
      [
              double("category1", id: 1, name: "Test", children: []),
      double("category2", id: 2, name: "Other", children: [])
      ]
    end
    let(:post_processor) { instance_double(Ai::PostProcessor) }

    before do
      allow(Current.user).to receive(:categories).and_return(user_categories)
      allow(Ai::PostProcessor).to receive(:new).and_return(post_processor)
    end

    context "when all batches succeed" do
      let(:batch1_result) { mock_response(success: true, payload: { "transactions" => [ { "description" => "Transaction 1", "category" => "Test" } ] }) }
      let(:batch2_result) { mock_response(success: true, payload: { "transactions" => [ { "description" => "Transaction 3", "category" => "Test" } ] }) }

      before do
        allow(post_processor).to receive(:call).and_return(batch1_result, batch2_result)
      end

      it "processes all batches and merges results" do
        result = service.send(:process_ai_enhancement_batches, batches, user_categories)

        # Now processes each transaction individually: 2 batches × 2 transactions = 4 calls
        expect(post_processor).to have_received(:call).exactly(4).times
        # Now we get 4 transactions (2 per batch) since each is processed individually
        expect(result["transactions"].count).to eq(4)
        expect(result["extraction_source"]).to eq("ai_enhanced_parser")
      end
    end

    context "when some batches fail" do
      let(:batch1_result) { mock_response(success: true, payload: { "transactions" => [ { "description" => "Transaction 1", "category" => "Test" } ] }) }
      let(:batch2_result) { mock_response(success: false, payload: nil) }

      before do
        allow(post_processor).to receive(:call).and_return(batch1_result, batch2_result)
      end

      it "continues processing and returns successful results" do
        result = service.send(:process_ai_enhancement_batches, batches, user_categories)

        # Now processes each transaction individually: 2 batches × 2 transactions = 4 calls
        expect(post_processor).to have_received(:call).exactly(4).times
        expect(result["transactions"].count).to eq(1)
        expect(result["extraction_source"]).to eq("ai_enhanced_parser")
      end
    end

    context "when all batches fail" do
      let(:batch1_result) { mock_response(success: false, payload: nil) }
      let(:batch2_result) { mock_response(success: false, payload: nil) }

      before do
        allow(post_processor).to receive(:call).and_return(batch1_result, batch2_result)
      end

      it "returns nil" do
        result = service.send(:process_ai_enhancement_batches, batches, user_categories)

        # Now processes each transaction individually: 2 batches × 2 transactions = 4 calls
        expect(post_processor).to have_received(:call).exactly(4).times
        expect(result).to be_nil
      end
    end
  end

  describe "#parse_with_ai" do
    let(:user_categories) { [] }

    before do
      allow(Current.user).to receive(:categories).and_return(user_categories)
    end

    context "when AI API is available" do
      before do
        allow(service).to receive(:ai_api_available?).and_return(true)
      end

      context "with single chunk" do
        let(:text_chunks) { [ "single chunk" ] }

        before do
          allow(Ai::PostProcessor).to receive(:new).and_return(
            double(call: mock_response(success: true, payload: { "transactions" => [ { "id" => 1 } ] }))
          )
        end

        it "processes single chunk with AI" do
          result = service.send(:parse_with_ai, text_data[:text_chunks], text_data[:text])

          expect(result).to be_present
          expect(result["transactions"]).to be_present
        end
      end

      context "with multiple chunks" do
        before do
          allow(service).to receive(:process_multiple_chunks).and_return({ "transactions" => [] })
        end

        it "processes multiple chunks" do
          result = service.send(:parse_with_ai, text_data[:text_chunks], text_data[:text])

                  expect(service).to have_received(:process_multiple_chunks)
          .with(text_data[:text_chunks], user_categories, text_data[:text]).at_least(:once)
        end
      end
    end

    context "when AI API is not available" do
      before do
        allow(service).to receive(:ai_api_available?).and_return(false)
      end

      it "returns nil" do
        result = service.send(:parse_with_ai, text_data[:text_chunks], text_data[:filtered_text])

        expect(result).to be_nil
      end
    end
  end

  describe "#parse_with_deterministic_parser" do
    let(:parser_type) { "bbva" }
    let(:parser_class) { double("parser_class") }

    before do
      allow(bank_account).to receive(:parser_type).and_return(parser_type)
      allow(bank_account).to receive(:parser_class).and_return(parser_class)
      allow(parser_class).to receive(:call).and_return(double(success?: true, payload: { "transactions" => [] }))
    end

    it "creates parser and parses text" do
      result = service.send(:parse_with_deterministic_parser, text_data[:text])

      expect(bank_account).to have_received(:parser_class)
      expect(result).to be_present
    end

    context "when parser fails" do
      before do
        allow(parser_class).to receive(:call).and_return(double(success?: false, errors: double(full_messages: [ "Parser error" ])))
        allow(service).to receive(:parse_with_generic_parser).and_return({ "transactions" => [] })
      end

      it "falls back to generic parser" do
        result = service.send(:parse_with_deterministic_parser, text_data[:text])

        expect(service).to have_received(:parse_with_generic_parser).with(text_data[:text])
        expect(result).to be_present
      end
    end
  end

  describe "#merge_ai_categorization_with_parser_transactions" do
    let(:parser_result) do
      {
        "transactions" => [
          { "date" => "2024-01-01", "amount" => -100.0, "description" => "Restaurant" }
        ],
        "opening_balance" => 1000.0,
        "closing_balance" => 900.0
      }
    end

    let(:ai_result) do
      {
        "transactions" => [
          { "id" => "TX_0", "date" => "2024-01-01", "amount" => -100.0, "description" => "Restaurant", "category" => "food" }
        ]
      }
    end

    it "merges AI categorization with parser transactions" do
      result = service.send(:merge_ai_categorization_with_parser_transactions, parser_result, ai_result)

      expect(result["opening_balance"]).to eq(1000.0)
      expect(result["closing_balance"]).to eq(900.0)
      expect(result["transactions"].first["category"]).to eq("food")
    end
  end

  describe "#create_transaction_key" do
    let(:transaction) do
      {
        "date" => "2024-01-01",
        "amount" => -100.0,
        "description" => "Restaurant ABC"
      }
    end

    it "creates multiple key variations for matching" do
      keys = service.send(:create_transaction_key, transaction)

      expect(keys).to be_an(Array)
      expect(keys.length).to eq(2)
      expect(keys.first).to include("2024-01-01")
      expect(keys.first).to include("100.0")
      expect(keys.first).to include("restaurant")
    end
  end

  describe "#determine_extraction_source" do
    context "when result has OCR source" do
      let(:result) { { "extraction_source" => "ocr" } }

      it "preserves OCR source" do
        source = service.send(:determine_extraction_source, result, "default_source")

        expect(source).to eq("ocr")
      end
    end

    context "when result has no extraction source" do
      let(:result) { {} }

      it "uses default source" do
        source = service.send(:determine_extraction_source, result, "default_source")

        expect(source).to eq("default_source")
      end
    end
  end
end
