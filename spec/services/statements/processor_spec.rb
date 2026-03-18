# spec/services/statements/processor_spec.rb
require "rails_helper"

RSpec.describe Statements::Processor do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "BBVA Bancomer", supported_type: :both) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank, account_type: "debit") }
  let(:statement_file) do
    create(:statement_file, user: user, bank_account: bank_account, processing_strategy: :text_with_ai)
  end

  let(:extracted_data) do
    {
      transactions: [
        {
          "date" => "2024-01-15",
          "description" => "OXXO Purchase",
          "amount" => -50.00,
          "reference" => "REF123"
        },
        {
          "date" => "2024-01-16",
          "description" => "Salary Deposit",
          "amount" => 5000.00,
          "reference" => "NOM001"
        }
      ],
      financial_summaries: [],
      opening_balance: 1000.00,
      closing_balance: 5950.00,
      extraction_source: "ai_vision"
    }
  end

  let(:vision_extractor_result) do
    ApplicationService::Response.new(
      success: true,
      payload: extracted_data,
      errors: nil
    )
  end

  let(:pii_handler_result) do
    ApplicationService::Response.new(
      success: true,
      payload: extracted_data,
      errors: nil
    )
  end

  let(:importer_result) do
    ApplicationService::Response.new(
      success: true,
      payload: { duplicates_found: false },
      errors: nil
    )
  end

  let(:status_manager_result) do
    ApplicationService::Response.new(
      success: true,
      payload: :completed,
      errors: nil
    )
  end

  let(:ai_post_processor_result) do
    ApplicationService::Response.new(
      success: true,
      payload: {
        "transactions" => extracted_data[:transactions],
        "financial_summaries" => [],
        "extraction_source" => "ai_post_processor_text"
      },
      errors: nil
    )
  end

  # Shared setup for mocking services
  before do
    # Mock file handling
    allow_any_instance_of(described_class).to receive(:create_temp_file).and_return(
      double("TempFile", path: "/tmp/mock_statement.pdf", close!: nil)
    )
    allow_any_instance_of(described_class).to receive(:cleanup_temp_file)

    # Default: Text extraction fails (will trigger vision path)
    allow(TextExtractor).to receive(:extract_text_layer).and_return("")
    allow(TextExtractor).to receive(:valid_text?).and_return(false)

    # Mock vision extractor
    allow(Statements::VisionExtractor).to receive(:call).and_return(vision_extractor_result)

    # Mock PII handler
    allow(Statements::PiiHandler).to receive(:redact_text).and_return(
      { redacted_text: "redacted text", map: {} }
    )
    allow(Statements::PiiHandler).to receive(:restore).and_return(pii_handler_result)

    # Mock AI services (categorization included in PostProcessor call)
    allow(Ai::PostProcessor).to receive(:call).and_return(ai_post_processor_result)

    # Mock importer
    allow_any_instance_of(Transactions::Importer).to receive(:call).and_return(importer_result)

    # Mock status manager
    allow(Statements::StatusManager).to receive(:call) do |sf, _payload|
      sf.update!(status: :completed)
      status_manager_result
    end

    # Mock financial summary creator
    allow(Statements::FinancialSummaryCreator).to receive(:call).and_return(
      ApplicationService::Response.new(success: true, payload: nil, errors: nil)
    )
  end

  describe "#call" do
    it "updates status to processing at start" do
      result = described_class.call(statement_file.id)

      expect(result).to be_success
      expect(statement_file.reload.status).to eq("completed")
    end

    context "when text extraction succeeds" do
      before do
        allow(TextExtractor).to receive(:extract_text_layer).and_return("Valid statement text with dates 01/15/2024")
        allow(TextExtractor).to receive(:valid_text?).and_return(true)
      end

      context "with processing_strategy=text_with_ai" do
        it "uses text + AI path (PII protected)" do
          expect(Statements::PiiHandler).to receive(:redact_text)
          expect(Ai::PostProcessor).to receive(:call)
          expect(Statements::PiiHandler).to receive(:restore)
          expect(Statements::VisionExtractor).not_to receive(:call)

          described_class.call(statement_file.id)
        end

        it "redacts PII before AI structuring" do
          call_order = []

          allow(Statements::PiiHandler).to receive(:redact_text) do
            call_order << :redact_pii
            { redacted_text: "redacted", map: {} }
          end

          allow(Ai::PostProcessor).to receive(:call) do
            call_order << :ai_structure
            ai_post_processor_result
          end

          described_class.call(statement_file.id)

          expect(call_order).to eq([:redact_pii, :ai_structure])
        end

        it "restores PII after AI structuring" do
          expect(Statements::PiiHandler).to receive(:restore).and_return(pii_handler_result)

          described_class.call(statement_file.id)
        end

        it "includes categorization in the single AI call (no separate categorizer)" do
          # Categorization is now handled by Ai::PostProcessor in a single call
          # Verify only one AI service is called for extraction + categorization
          expect(Ai::PostProcessor).to receive(:call).once.and_return(ai_post_processor_result)

          described_class.call(statement_file.id)
        end

        context "when text processing yields no transactions" do
          let(:empty_ai_result) do
            ApplicationService::Response.new(
              success: true,
              payload: { "transactions" => [], "financial_summaries" => [] },
              errors: nil
            )
          end

          before do
            allow(Ai::PostProcessor).to receive(:call).and_return(empty_ai_result)
            allow(Statements::PiiHandler).to receive(:restore).and_return(
              ApplicationService::Response.new(success: true, payload: empty_ai_result.payload, errors: nil)
            )
          end

          it "falls back to vision extraction" do
            expect(Statements::VisionExtractor).to receive(:call).and_return(vision_extractor_result)

            described_class.call(statement_file.id)
          end
        end
      end

      context "with processing_strategy=parser_only" do
        let(:statement_file) do
          create(:statement_file, user: user, bank_account: bank_account, processing_strategy: :parser_only)
        end

        let(:parser_result) do
          ApplicationService::Response.new(
            success: true,
            payload: { "transactions" => extracted_data[:transactions], "extraction_source" => "deterministic_parser" },
            errors: nil
          )
        end

        before do
          allow(bank_account).to receive(:parser_class).and_return(PdfParser::Generic)
          allow(PdfParser::Generic).to receive(:call).and_return(parser_result)
        end

        it "uses deterministic parser only (no AI, no categorization)" do
          expect(PdfParser::Generic).to receive(:call)
          expect(Ai::PostProcessor).not_to receive(:call)
          expect(Statements::VisionExtractor).not_to receive(:call)

          described_class.call(statement_file.id)
        end

        it "does not redact PII (no AI involved)" do
          expect(Statements::PiiHandler).not_to receive(:redact_text)

          described_class.call(statement_file.id)
        end

        context "when parser yields no transactions" do
          let(:empty_parser_result) do
            ApplicationService::Response.new(
              success: true,
              payload: { "transactions" => [] },
              errors: nil
            )
          end

          before do
            allow(PdfParser::Generic).to receive(:call).and_return(empty_parser_result)
          end

          it "does NOT fall back to vision (parser_only strategy)" do
            expect(Statements::VisionExtractor).not_to receive(:call)

            result = described_class.call(statement_file.id)
            # Still succeeds, just with no transactions
            expect(result).to be_success
          end
        end

        context "when bank requires AI (parser_class is Ai::PostProcessor)" do
          before do
            allow_any_instance_of(BankAccount).to receive(:parser_class).and_return(Ai::PostProcessor)
          end

          it "returns failure with helpful error" do
            result = described_class.call(statement_file.id)

            expect(result).to be_failure
            expect(statement_file.reload.error_message).to include("requires AI processing")
          end
        end
      end
    end

    context "when text extraction fails" do
      before do
        allow(TextExtractor).to receive(:extract_text_layer).and_return("")
        allow(TextExtractor).to receive(:valid_text?).and_return(false)
      end

      context "with processing_strategy=text_with_ai" do
        it "uses vision extraction path" do
          expect(Statements::VisionExtractor).to receive(:call).and_return(vision_extractor_result)

          described_class.call(statement_file.id)
        end

        it "does not redact PII (AI already saw document)" do
          expect(Statements::PiiHandler).not_to receive(:redact_text)

          described_class.call(statement_file.id)
        end

        it "returns success with statement file" do
          result = described_class.call(statement_file.id)

          expect(result).to be_success
          expect(result.payload).to eq(statement_file)
        end
      end

      context "with processing_strategy=parser_only" do
        let(:statement_file) do
          create(:statement_file, user: user, bank_account: bank_account, processing_strategy: :parser_only)
        end

        it "returns failure (cannot process without AI)" do
          result = described_class.call(statement_file.id)

          expect(result).to be_failure
          expect(statement_file.reload.status).to eq("error")
          expect(statement_file.error_message).to include("without AI")
        end
      end
    end

    context "when the file is missing from storage" do
      before do
        allow_any_instance_of(described_class).to receive(:create_temp_file)
          .and_raise(ActiveStorage::FileNotFoundError)
      end

      it "returns failure" do
        result = described_class.call(statement_file.id)

        expect(result).to be_failure
      end

      it "sets status to error" do
        described_class.call(statement_file.id)

        expect(statement_file.reload.status).to eq("error")
      end

      it "sets a re-upload error message" do
        described_class.call(statement_file.id)

        expect(statement_file.reload.error_message).to include("re-upload")
      end
    end

    context "when vision extraction fails" do
      let(:failed_extraction_result) do
        errors = ActiveModel::Errors.new(nil)
        errors.add(:base, "Vision API error")
        ApplicationService::Response.new(
          success: false,
          payload: nil,
          errors: errors
        )
      end

      before do
        allow(TextExtractor).to receive(:valid_text?).and_return(false)
        allow(Statements::VisionExtractor).to receive(:call).and_return(failed_extraction_result)
      end

      it "sets statement status to error" do
        described_class.call(statement_file.id)

        expect(statement_file.reload.status).to eq("error")
      end

      it "stores error message" do
        described_class.call(statement_file.id)

        expect(statement_file.reload.error_message).to include("Vision extraction failed")
      end

      it "returns failure" do
        result = described_class.call(statement_file.id)

        expect(result).to be_failure
      end
    end

    context "when import fails" do
      let(:failed_importer_result) do
        errors = ActiveModel::Errors.new(nil)
        errors.add(:base, "Import failed")
        ApplicationService::Response.new(
          success: false,
          payload: nil,
          errors: errors
        )
      end

      before do
        allow_any_instance_of(Transactions::Importer).to receive(:call).and_return(failed_importer_result)
      end

      it "sets statement status to error" do
        described_class.call(statement_file.id)

        expect(statement_file.reload.status).to eq("error")
      end

      it "returns failure" do
        result = described_class.call(statement_file.id)

        expect(result).to be_failure
      end
    end

    context "when duplicates are found" do
      let(:importer_result_with_duplicates) do
        ApplicationService::Response.new(
          success: true,
          payload: { duplicates_found: true },
          errors: nil
        )
      end

      let(:status_parsed_result) do
        ApplicationService::Response.new(
          success: true,
          payload: :parsed,
          errors: nil
        )
      end

      before do
        allow_any_instance_of(Transactions::Importer).to receive(:call).and_return(importer_result_with_duplicates)
        allow(Statements::StatusManager).to receive(:call).and_return(status_parsed_result)
      end

      it "calls status manager with duplicate info" do
        expect(Statements::StatusManager).to receive(:call).with(
          statement_file,
          { duplicates_found: true }
        )

        described_class.call(statement_file.id)
      end
    end

    context "with financial summaries" do
      let(:data_with_summaries) do
        {
          "transactions" => [],
          "financial_summaries" => [
            {
              "period_start" => "2024-01-01",
              "period_end" => "2024-01-31",
              "total_deposits" => 5000.00
            }
          ],
          "opening_balance" => 1000.00,
          "closing_balance" => 5950.00,
          "extraction_source" => "ai_vision"
        }
      end

      let(:vision_with_summaries) do
        ApplicationService::Response.new(
          success: true,
          payload: data_with_summaries,
          errors: nil
        )
      end

      before do
        allow(Statements::VisionExtractor).to receive(:call).and_return(vision_with_summaries)
      end

      it "creates financial summaries" do
        expect(Statements::FinancialSummaryCreator).to receive(:call).with(statement_file, anything)

        described_class.call(statement_file.id)
      end
    end
  end
end
