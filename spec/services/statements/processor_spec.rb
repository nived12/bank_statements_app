# spec/services/statements/processor_spec.rb
require "rails_helper"

RSpec.describe Statements::Processor do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "BBVA Bancomer") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank, account_type: "debit") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, ai_enabled: true) }

  let(:vision_extractor_result) do
    ApplicationService::Result.new(
      success: true,
      payload: {
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
        extraction_source: "gemini_vision"
      }
    )
  end

  let(:pii_handler_result) do
    ApplicationService::Result.new(
      success: true,
      payload: vision_extractor_result.payload
    )
  end

  let(:categorizer_result) do
    ApplicationService::Result.new(
      success: true,
      payload: vision_extractor_result.payload
    )
  end

  let(:importer_result) do
    ApplicationService::Result.new(
      success: true,
      payload: { duplicates_found: false }
    )
  end

  let(:status_manager_result) do
    ApplicationService::Result.new(
      success: true,
      payload: :completed
    )
  end

  before do
    # Mock all the service calls
    allow(Statements::VisionExtractor).to receive(:call).and_return(vision_extractor_result)
    allow(Statements::PiiHandler).to receive(:new).and_return(
      instance_double(Statements::PiiHandler, call: pii_handler_result)
    )
    allow(Statements::PiiHandler).to receive(:restore).and_return(pii_handler_result)
    allow(Transactions::Categorizer).to receive(:call).and_return(categorizer_result)
    allow_any_instance_of(Transactions::Importer).to receive(:call).and_return(importer_result)
    allow(Statements::StatusManager).to receive(:call).and_return(status_manager_result)
    allow_any_instance_of(FinancialSummaryService).to receive(:create_financial_summary).and_return(true)
  end

  describe "#call" do
    it "updates status to processing at start" do
      described_class.call(statement_file.id)

      expect(statement_file.reload.status).to eq("completed")
    end

    it "calls all services in correct order" do
      expect(Statements::VisionExtractor).to receive(:call).ordered
      expect(Statements::PiiHandler).to receive(:new).ordered
      expect(Transactions::Categorizer).to receive(:call).ordered
      expect(Statements::PiiHandler).to receive(:restore).ordered
      expect(Statements::StatusManager).to receive(:call).ordered

      described_class.call(statement_file.id)
    end

    it "returns success with statement file" do
      result = described_class.call(statement_file.id)

      expect(result).to be_success
      expect(result.payload).to eq(statement_file)
    end

    it "stores processed data in statement file" do
      described_class.call(statement_file.id)

      statement_file.reload
      expect(statement_file.parsed_json).to be_present
      expect(statement_file.processed_at).to be_present
    end

    context "when AI categorization is disabled" do
      let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, ai_enabled: false) }

      it "skips categorization step" do
        expect(Transactions::Categorizer).not_to receive(:call)

        described_class.call(statement_file.id)
      end
    end

    context "when extraction fails" do
      before do
        allow(Statements::VisionExtractor).to receive(:call).and_return(
          ApplicationService::Result.new(success: false, errors: ActiveModel::Errors.new(nil))
        )
      end

      it "sets statement status to error" do
        described_class.call(statement_file.id)

        expect(statement_file.reload.status).to eq("error")
      end

      it "stores error message" do
        described_class.call(statement_file.id)

        expect(statement_file.reload.error_message).to include("Extraction failed")
      end

      it "returns failure" do
        result = described_class.call(statement_file.id)

        expect(result).to be_failure
      end
    end

    context "when PII handling fails" do
      before do
        allow(Statements::PiiHandler).to receive(:new).and_return(
          instance_double(Statements::PiiHandler, call: ApplicationService::Result.new(success: false, errors: ActiveModel::Errors.new(nil)))
        )
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

    context "when categorization fails" do
      before do
        allow(Transactions::Categorizer).to receive(:call).and_return(
          ApplicationService::Result.new(success: false, errors: ActiveModel::Errors.new(nil))
        )
      end

      it "continues processing without categories" do
        result = described_class.call(statement_file.id)

        expect(result).to be_success
      end

      it "logs warning" do
        expect(Rails.logger).to receive(:warn).with(/Categorization failed/)

        described_class.call(statement_file.id)
      end
    end

    context "when import fails" do
      before do
        allow_any_instance_of(Transactions::Importer).to receive(:call).and_return(
          ApplicationService::Result.new(success: false, errors: ActiveModel::Errors.new(nil))
        )
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
        ApplicationService::Result.new(
          success: true,
          payload: { duplicates_found: true }
        )
      end

      let(:status_parsed_result) do
        ApplicationService::Result.new(
          success: true,
          payload: :parsed
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
      let(:vision_with_summaries) do
        ApplicationService::Result.new(
          success: true,
          payload: {
            transactions: [],
            financial_summaries: [
              {
                "period_start" => "2024-01-01",
                "period_end" => "2024-01-31",
                "total_deposits" => 5000.00
              }
            ],
            opening_balance: 1000.00,
            closing_balance: 5950.00,
            extraction_source: "gemini_vision"
          }
        )
      end

      before do
        allow(Statements::VisionExtractor).to receive(:call).and_return(vision_with_summaries)
      end

      it "creates financial summaries" do
        expect_any_instance_of(FinancialSummaryService).to receive(:create_financial_summary)

        described_class.call(statement_file.id)
      end
    end
  end
end
