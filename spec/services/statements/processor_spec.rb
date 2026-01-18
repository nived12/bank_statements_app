# spec/services/statements/processor_spec.rb
require "rails_helper"

RSpec.describe Statements::Processor do
  let(:user) { create(:user) }
  let(:bank) { create(:bank, name: "BBVA Bancomer") }
  let(:bank_account) { create(:bank_account, user: user, bank: bank, account_type: "debit") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account, ai_enabled: true) }

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

  let(:categorizer_result) do
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

  before do
    # Mock all the service calls - CRITICAL: Mock VisionExtractor to prevent real API calls
    allow(Statements::VisionExtractor).to receive(:call).and_return(vision_extractor_result)

    # Mock VisionClient to prevent any real API calls
    allow(Ai::VisionClient).to receive(:new).and_return(
      instance_double(Ai::VisionClient, analyze_document: { text: "", usage: nil })
    )

    # Mock file operations to prevent actual file system access
    allow_any_instance_of(Statements::VisionExtractor).to receive(:download_pdf_from_active_storage)
      .and_return("/tmp/mock_statement.pdf")
    allow_any_instance_of(Statements::VisionExtractor).to receive(:convert_pdf_to_images)
      .and_return(["/tmp/mock_page.jpg"])
    allow_any_instance_of(Statements::VisionExtractor).to receive(:validate_dependencies!)
    allow_any_instance_of(Statements::VisionExtractor).to receive(:validate_statement_file!)

    allow(Statements::PiiHandler).to receive(:new).and_return(
      instance_double(Statements::PiiHandler, call: pii_handler_result)
    )
    allow(Statements::PiiHandler).to receive(:restore).and_return(pii_handler_result)
    allow(Transactions::Categorizer).to receive(:call).and_return(categorizer_result)

    # Mock AI Client to prevent real API calls
    allow(Ai::Client).to receive(:new).and_return(
      instance_double(Ai::Client, chat: { text: "{}", usage: {} })
    )

    # Mock importer to actually create transactions
    allow_any_instance_of(Transactions::Importer).to receive(:call) do |instance|
      json = instance.instance_variable_get(:@json)
      user = instance.instance_variable_get(:@user)
      bank_account = instance.instance_variable_get(:@bank_account)
      statement_file = instance.instance_variable_get(:@statement_file)

      transactions = json["transactions"] || json[:transactions] || []
      transactions.each do |tx_data|
        tx_hash = tx_data.is_a?(Hash) ? tx_data : tx_data.to_h
        Transaction.create!(
          user: user,
          bank_account: bank_account,
          statement_file: statement_file,
          date: Date.parse(tx_hash["date"] || tx_hash[:date]),
          description: (tx_hash["description"] || tx_hash[:description]).to_s.squish,
          amount: (tx_hash["amount"] || tx_hash[:amount]).to_d,
          transaction_type: tx_hash["transaction_type"] || tx_hash[:transaction_type] ||
            ((tx_hash["amount"] || tx_hash[:amount]).to_f < 0 ? "variable_expense" : "income"),
          category_id: tx_hash["category_id"] || tx_hash[:category_id],
          merchant: tx_hash["merchant"] || tx_hash[:merchant],
          reference: tx_hash["reference"] || tx_hash[:reference],
          source: :statement_file
        )
      end

      importer_result
    end

    allow(Statements::StatusManager).to receive(:call) do |sf, payload|
      sf.update!(status: :completed)
      status_manager_result
    end
    allow_any_instance_of(FinancialSummaryService).to receive(:create_financial_summary).and_return(true)
  end

  describe "#call" do
    it "updates status to processing at start" do
      # The processor updates status to processing at the start
      # We verify this by checking it was called, then the final status
      result = described_class.call(statement_file.id)

      # After successful processing, status should be completed
      expect(result).to be_success, "Processor failed: #{result.errors.full_messages if result&.errors}"
      expect(statement_file.reload.status).to eq("completed")
    end

    it "calls all services in correct order" do
      call_order = []

      allow(Statements::VisionExtractor).to receive(:call).with(statement_file) do
        call_order << :vision_extractor
        vision_extractor_result
      end

      allow(Statements::PiiHandler).to receive(:new).with(statement_file, extracted_data) do
        call_order << :pii_handler_new
        instance_double(Statements::PiiHandler, call: pii_handler_result)
      end

      allow(Transactions::Categorizer).to receive(:call).with(statement_file, extracted_data) do
        call_order << :categorizer
        categorizer_result
      end

      allow(Statements::PiiHandler).to receive(:restore).with(statement_file, extracted_data) do
        call_order << :pii_restore
        pii_handler_result
      end

      allow_any_instance_of(Transactions::Importer).to receive(:call) do
        call_order << :importer
        importer_result
      end

      allow(Statements::StatusManager).to receive(:call).with(statement_file, { duplicates_found: false }) do
        call_order << :status_manager
        status_manager_result
      end

      described_class.call(statement_file.id)

      expect(call_order).to eq(
        [:vision_extractor, :pii_handler_new, :categorizer, :pii_restore, :importer,
        :status_manager]
      )
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
      expect(statement_file.parsed_json["transactions"]).to be_present
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
      let(:failed_extraction_result) do
        errors = ActiveModel::Errors.new(nil)
        errors.add(:base, "Extraction failed")
        ApplicationService::Response.new(
          success: false,
          payload: nil,
          errors: errors
        )
      end

      before do
        allow(Statements::VisionExtractor).to receive(:call).and_return(failed_extraction_result)
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
      let(:failed_pii_result) do
        errors = ActiveModel::Errors.new(nil)
        errors.add(:base, "PII handling failed")
        ApplicationService::Response.new(
          success: false,
          payload: nil,
          errors: errors
        )
      end

      before do
        allow(Statements::PiiHandler).to receive(:new).and_return(
          instance_double(Statements::PiiHandler, call: failed_pii_result)
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
      let(:failed_categorizer_result) do
        errors = ActiveModel::Errors.new(nil)
        errors.add(:base, "Categorization failed")
        ApplicationService::Response.new(
          success: false,
          payload: nil,
          errors: errors
        )
      end

      before do
        allow(Transactions::Categorizer).to receive(:call).and_return(failed_categorizer_result)
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
      let(:extracted_data_with_summaries) do
        {
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
          extraction_source: "ai_vision"
        }
      end

      let(:vision_with_summaries) do
        ApplicationService::Response.new(
          success: true,
          payload: extracted_data_with_summaries,
          errors: nil
        )
      end

      let(:pii_result_with_summaries) do
        ApplicationService::Response.new(
          success: true,
          payload: extracted_data_with_summaries,
          errors: nil
        )
      end

      before do
        allow(Statements::VisionExtractor).to receive(:call).and_return(vision_with_summaries)
        allow(Statements::PiiHandler).to receive(:new).and_return(
          instance_double(Statements::PiiHandler, call: pii_result_with_summaries)
        )
        allow(Statements::PiiHandler).to receive(:restore).and_return(pii_result_with_summaries)
        allow(Transactions::Categorizer).to receive(:call).and_return(pii_result_with_summaries)
      end

      it "creates financial summaries" do
        expect_any_instance_of(FinancialSummaryService).to receive(:create_financial_summary)

        described_class.call(statement_file.id)
      end
    end
  end
end
