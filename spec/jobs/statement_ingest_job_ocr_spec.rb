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
        "transaction_type" => "income",
        "bank_entry_type" => "credit"
      },
      {
        "date" => "2025-01-05",
        "description" => "Amazon Marketplace",
        "amount" => -1_299.99,
        "transaction_type" => "variable_expense",
        "bank_entry_type" => "debit"
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
    # Mock the AI Post Processor since the generic bank is not supported
    response_payload = mock_parser_response.merge("extraction_source" => "ocr")
    success_response = double("Response", success?: true, payload: response_payload)
    allow_any_instance_of(Ai::PostProcessor).to receive(:call).and_return(success_response)
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
          "bank_entry_type" => "credit"
        )
        expect(first_tx["amount"]).to eq(15000.0)

        # Test second transaction (expense)
        second_tx = transactions.second
        expect(second_tx).to include(
          "transaction_type" => "variable_expense",
          "bank_entry_type" => "debit"
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
        expect(db_transactions.pluck(:bank_entry_type)).to contain_exactly("credit", "debit")
      end
    end
  end

  private

  def setup_ocr_environment
    # Force empty text layer to trigger OCR
    allow(TextExtractor).to receive(:extract_text_layer).and_return("")

    # Mock OCR service to return test data
    allow(OcrService).to receive(:call).and_return(double(success?: true, payload: ocr_test_text))

    # Disable AI processing for deterministic testing
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AI_PROVIDER").and_return(nil)
    allow(ENV).to receive(:[]).with("AI_API_KEY").and_return(nil)
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
