require "rails_helper"

RSpec.describe StatementIngestJob, type: :job do
  # Use a generic bank for OCR testing to avoid hybrid parsing complexity
  let(:generic_bank) { create(:bank, :generic) }
  let(:bank_account) { create(:bank_account, :with_custom_name, bank: generic_bank) }
  let(:statement_file) { create(:statement_file, bank_account: bank_account) }

  # Extract test data to constants for reusability
  let(:expected_transactions) do
    [
      {
        "date" => "2025-01-03",
        "description" => "Pago Nomina EMPRESA SA",
        "amount" => 15_000.0,
        "transaction_type" => "income"
      },
      {
        "date" => "2025-01-05",
        "description" => "Amazon Marketplace",
        "amount" => -1_299.99,
        "transaction_type" => "variable_expense"
      }
    ]
  end

  let(:mock_parser_response) do
    {
      "opening_balance" => 0.0,
      "closing_balance" => 0.0,
      "transactions" => expected_transactions
    }
  end

  subject(:perform_job) { described_class.perform_now(statement_file.id) }

  before do
    setup_ocr_environment
    setup_orchestrator_mocks_for_ocr
    setup_parser_service_mocks_for_ocr
    setup_importer_mocks
  end

  describe "#perform" do
    context "when OCR provides text" do
      it "parses transactions and updates statement file status" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq("completed")
        expect(statement_file.parsed_json["extraction_source"]).to eq("ocr")
      end

      it "extracts correct transaction data" do
        perform_job
        statement_file.reload

        transactions = statement_file.parsed_json["transactions"]
        expect(transactions).to have_attributes(size: 2)

        # Test first transaction (income)
        first_tx = transactions.first
        expect(first_tx).to include(
          "transaction_type" => "income",
        )
        expect(first_tx["amount"]).to eq(15000.0)

        # Test second transaction (expense)
        second_tx = transactions.second
        expect(second_tx).to include(
          "transaction_type" => "variable_expense",
        )
        expect(second_tx["amount"]).to eq(-1299.99)
      end

      it "creates transaction records in database" do
        expect { perform_job }.to change { Transaction.count }.by(2)

        # Verify transactions are associated with the statement file
        db_transactions = Transaction.where(statement_file: statement_file)
        expect(db_transactions.count).to eq(2)

        # Verify transaction types match expected values
        expect(db_transactions.pluck(:transaction_type)).to contain_exactly("income", "variable_expense")
      end
    end
  end

  private

  def setup_ocr_environment
    # Force empty text layer to trigger OCR
    allow(TextExtractor).to receive(:extract_text_layer).and_return("")
    allow(TextExtractor).to receive(:valid_text?).and_return(false).and_return(true)

    # Mock OCR service to return test data
    allow(OcrService).to receive(:call).and_return(double(success?: true, payload: ocr_test_text))

    # Disable AI processing for deterministic testing
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_PROVIDER").and_return(nil)
    allow(ENV).to receive(:[]).with("AI_API_KEY").and_return(nil)
    allow(ENV).to receive(:[]).with("USE_VISION_PROCESSOR").and_return(nil)

    # CRITICAL: Mock all AI clients to prevent real API calls
    allow(Ai::VisionClient).to receive(:new).and_return(
      instance_double(Ai::VisionClient, analyze_document: { text: "{}", usage: nil })
    )
    allow(Ai::Client).to receive(:new).and_return(
      instance_double(Ai::Client, chat: "{}")
    )
  end

  def setup_orchestrator_mocks_for_ocr
    # Mock temp file creation
    temp_file = double("TempFile", path: "/tmp/test_statement.pdf")
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:create_temp_file)
      .and_return(temp_file)
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:cleanup_temp_file)

    # Mock text extraction with OCR
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:extract_and_process_text) do |_instance, _path, _statement|
      {
        text: ocr_test_text,
        text_chunks: [ocr_test_text],
        financial_data: {},
        source: "ocr"
      }
    end

    # Mock PII redaction
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:pii_redaction_enabled?).and_return(false)
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:restore_pii_tokens) do |_instance, parsed, _statement|
      parsed
    end

    # Mock financial summaries creation
    allow_any_instance_of(StatementProcessingOrchestrator).to receive(:create_financial_summaries)
  end

  def setup_parser_service_mocks_for_ocr
    # For unsupported banks, orchestrator uses Ai::PostProcessor directly
    # Mock it to return the expected transactions
    response_payload = mock_parser_response.merge("extraction_source" => "ocr")
    ai_result = double(
      "AiResult",
      success?: true,
      payload: response_payload,
      errors: double("Errors", full_messages: [])
    )
    allow(Ai::PostProcessor).to receive(:call).and_return(ai_result)
  end

  def setup_importer_mocks
    # Mock duplicate detector to return no duplicates, then allow real importer to run
    allow(Transactions::DuplicateDetector).to receive(:call).and_return(
      ApplicationService::Response.new(
        success: true,
        payload: [],
        errors: nil
      )
    )

    # Allow real importer to run so transactions are actually created
    allow_any_instance_of(Transactions::Importer).to receive(:call) do |instance|
      # Call the real call method but with mocked duplicate detector
      instance.send(
        :import_non_duplicate_transactions,
        instance.instance_variable_get(:@user),
        instance.instance_variable_get(:@bank_account),
        []
      )
      ApplicationService::Response.new(
        success: true,
        payload: { duplicates_found: false },
        errors: nil
      )
    end
  end

  def setup_fallback_parser
    allow_any_instance_of(PdfParser::Generic).to receive(:parse).and_return(mock_parser_response)
  end

  def ocr_test_text
    <<~TXT
      03/01/2025 Pago Nomina EMPRESA SA 15,000.00
      05/01/2025 Amazon Marketplace -1,299.99
    TXT
  end
end
