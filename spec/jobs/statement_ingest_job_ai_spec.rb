require "rails_helper"

RSpec.describe StatementIngestJob, type: :job do
  let(:bank_account) do
    create(
      :bank_account,
      bank_name: "BBVA",
      account_number: "1234",
      currency: "MXN",
      opening_balance: 0.0
    )
  end

  let(:statement_file) { create(:statement_file, bank_account: bank_account) }

  subject(:perform_job) { described_class.perform_now(statement_file.id) }

  before do
    setup_environment_variables
    setup_text_extraction
    setup_ai_client
  end

  describe "#perform" do
    context "when AI API is available" do
      it "stores AI parsed JSON with transaction_type and bank_entry_type" do
        perform_job
        statement_file.reload

        expect(statement_file.status).to eq("parsed")
        expect(statement_file.parsed_json["extraction_source"]).to eq("text")

        transaction = statement_file.parsed_json["transactions"].first
        expect(transaction["transaction_type"]).to eq("income")
        expect(transaction["bank_entry_type"]).to eq("credit")
        expect(transaction["amount"]).to eq(15000.0)
      end
    end

    context "when PII redaction is enabled" do
      before do
        allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("1")
        allow(TextExtractor).to receive(:extract_text_layer)
          .and_return("Payment from juan.perez@example.com on 2025-08-01 amount 1200")
      end

      context "when redaction data exists" do
        let(:mock_processor) { instance_double(Ai::PostProcessor) }

        before do
          setup_ai_post_processor(mock_processor)
          setup_fallback_parser
        end

        it "persists redaction_map and redaction_hmac" do
          allow(mock_processor).to receive(:call).and_return({ "transactions" => [] })

          perform_job
          statement_file.reload

          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
        end

        it "restores PII tokens from AI output" do
          allow(mock_processor).to receive(:call).and_return(
            build_ai_response_with_tokens
          )

          perform_job
          statement_file.reload

          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
          expect(statement_file.parsed_json.dig("transactions", 0, "description"))
            .to eq("Payment from juan.perez@example.com")
          expect(statement_file.parsed_json["raw_text"])
            .to eq("Payment from juan.perez@example.com on 2025-08-01 amount 1200")
        end

        it "always sends masked text to AI, never original PII" do
          # Verify that the AI processor receives masked text, not original PII
          expect(mock_processor).to receive(:call) do |args|
            # The raw_text should contain tokens, not original PII
            expect(args[:raw_text]).to include("⟪PII:EMAIL:1⟫")
            expect(args[:raw_text]).not_to include("juan.perez@example.com")

            # Return a simple response for this test
            { "transactions" => [] }
          end

          perform_job
        end

                it "creates consistent redaction data for same text" do
          allow(mock_processor).to receive(:call).and_return(
            build_ai_response_with_tokens
          )

          # First run creates redaction data
          perform_job
          statement_file.reload
          first_hmac = statement_file.redaction_hmac

          # Second run creates fresh redaction data
          described_class.perform_now(statement_file.id)
          statement_file.reload
          second_hmac = statement_file.redaction_hmac

          # HMACs should be the same since the text and redaction process are identical
          expect(first_hmac).to eq(second_hmac)
          expect(statement_file.status).to eq("parsed")
        end
      end

      context "when no redaction data exists" do
        let(:mock_processor) { instance_double(Ai::PostProcessor) }

        before do
          statement_file.update!(redaction_map: nil, redaction_hmac: nil)
          setup_ai_post_processor(mock_processor)
          setup_fallback_parser
        end

        it "creates new redaction map and processes successfully" do
          allow(mock_processor).to receive(:call).and_return(
            build_ai_response_with_tokens
          )

          perform_job
          statement_file.reload

          expect(statement_file.status).to eq("parsed")
          expect(statement_file.redaction_map).to be_present
          expect(statement_file.redaction_hmac).to be_present
          expect(statement_file.parsed_json.dig("transactions", 0, "description"))
            .to eq("Payment from juan.perez@example.com")
        end
      end
    end

    context "when PII redaction is disabled" do
      let(:mock_processor) { instance_double(Ai::PostProcessor) }

      before do
        allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return(nil)
        setup_ai_post_processor(mock_processor)
        allow(mock_processor).to receive(:call).and_return({ "transactions" => [] })
      end

      it "does not persist redaction_map or redaction_hmac" do
        perform_job
        statement_file.reload

        expect(statement_file.redaction_map).to be_nil.or be_empty
        expect(statement_file.redaction_hmac).to be_nil.or be_empty
      end
    end
  end

  private

  def setup_environment_variables
    allow(ENV).to receive(:fetch).with("AI_API_KEY", "").and_return("fake_key")
    allow(ENV).to receive(:[]).with("PII_REDACTION_ENABLED").and_return("0")
    allow(ENV).to receive(:[]).and_call_original
  end

  def setup_text_extraction
    allow(TextExtractor).to receive(:extract_text_layer)
      .and_return("03/01/2025 Pago Nomina EMPRESA SA 15,000.00")
    allow(TextExtractor).to receive(:valid_text?).and_return(true)
  end

  def setup_ai_client
    fake_client = instance_double(Ai::Client)
    allow(Ai::Client).to receive(:new).and_return(fake_client)
    allow(fake_client).to receive(:chat).and_return(build_ai_response)
  end

  def setup_ai_post_processor(processor)
    allow(Ai::PostProcessor).to receive(:new).and_return(processor)
  end

  def setup_fallback_parser
    allow_any_instance_of(PdfParser::Generic).to receive(:parse).and_return({
      "opening_balance" => 0.0,
      "closing_balance" => 0.0,
      "transactions" => []
    })
  end

  def build_ai_response
    <<~JSON
      {
        "opening_balance": 12000.0,
        "closing_balance": 13000.0,
        "transactions": [
          {
            "date": "2025-01-03",
            "description": "Pago Nomina EMPRESA SA",
            "amount": 15000.0,
            "transaction_type": "income",
            "bank_entry_type": "credit",
            "merchant": null,
            "reference": null,
            "category": "Uncategorized",
            "sub_category": null,
            "raw_text": "03/01/2025 Pago Nomina EMPRESA SA 15,000.00",
            "confidence": 0.9
          }
        ]
      }
    JSON
  end

  def build_ai_response_with_tokens
    {
      "opening_balance" => 0.0,
      "closing_balance" => 0.0,
      "extraction_source" => "text",
      "raw_text" => "Payment from ⟪PII:EMAIL:1⟫ on 2025-08-01 amount 1200",
      "transactions" => [
        {
          "date" => "2025-08-01",
          "description" => "Payment from ⟪PII:EMAIL:1⟫",
          "amount" => 1200.0,
          "transaction_type" => "income",
          "bank_entry_type" => "credit"
        }
      ]
    }
  end
end
