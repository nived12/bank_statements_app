require "rails_helper"

RSpec.describe StatementIngestJob, type: :job do
  # Use a generic bank for OCR testing to avoid hybrid parsing complexity
  let(:generic_bank) { create(:bank, :generic) }
  let(:bank_account) { create(:bank_account, :with_custom_name, bank: generic_bank) }
  let(:statement_file) { create(:statement_file, bank_account: bank_account, processing_strategy: :vision_ai) }

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
    setup_vision_extractor_mocks
    setup_importer_mocks
  end

  describe "#perform" do
    context "when OCR provides text" do
      it "parses transactions and updates statement file status" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq("completed")
        expect(statement_file.parsed_json["extraction_source"]).to eq("ai_vision")
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
    # Set up environment variables
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")
    allow(ENV).to receive(:fetch).with("TRIAL_DURATION_DAYS", 30).and_return(30)
    allow(ENV).to receive(:[]).with("AI_API_KEY").and_return("fake_key")
    allow(ENV).to receive(:[]).with("AI_PROVIDER").and_return(nil)
    allow(ENV).to receive(:[]).with("AI_MODEL").and_return("gemini-2.0-flash-lite")
    allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("0")
    allow(ENV).to receive(:[]).with("USE_VISION_PROCESSOR").and_return(nil)

    # Mock Vision client to return OCR-like response
    vision_response = mock_parser_response.merge("financial_summaries" => []).to_json
    allow(Ai::VisionClient).to receive(:new).and_return(
      instance_double(Ai::VisionClient, analyze_document: { text: vision_response, usage: nil })
    )

    # Mock AI categorization client
    categorization_response = {
      "transactions" => expected_transactions.map do |tx|
        tx.merge(
          "category_id" => nil,
          "sub_category_id" => nil,
          "confidence" => 0.9,
          "category_confidence" => 0.85,
          "transaction_type_confidence" => 0.95
        )
      end
    }.to_json

    allow(Ai::Client).to receive(:new).and_return(
      instance_double(Ai::Client, chat: { text: categorization_response, usage: nil })
    )
  end

  def setup_vision_extractor_mocks
    # Mock VisionExtractor dependencies
    allow_any_instance_of(Statements::VisionExtractor).to receive(:validate_dependencies!)
    allow_any_instance_of(Statements::VisionExtractor).to receive(:convert_pdf_to_images)
      .and_return(["/tmp/page-001.jpg"])
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
end
