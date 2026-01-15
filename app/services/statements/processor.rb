# app/services/statements/processor.rb
module Statements
  class Processor < ApplicationService
    include ErrorHandling

    def initialize(statement_file_id)
      super()
      @statement_file = StatementFile.find(statement_file_id)
    end

    def call
      Rails.logger.info("Starting statement processing for statement #{@statement_file.id}")

      # Update status to processing (no transaction needed - single update)
      @statement_file.update(status: :processing)

      # Step 1: Extract transactions with AI Vision
      extraction_result = extract_with_vision
      return handle_failure("Extraction failed") unless extraction_result.success?

      extracted_data = extraction_result.payload

      # Step 2: Redact PII (before categorization)
      pii_result = redact_pii(extracted_data)
      return handle_failure("PII handling failed") unless pii_result.success?

      processed_data = pii_result.payload

      # Step 3: Categorize transactions with AI (if enabled)
      if @statement_file.ai_enabled?
        categorization_result = categorize_transactions(processed_data)
        if categorization_result.success?
          processed_data = categorization_result.payload
        else
          Rails.logger.warn("Categorization failed, continuing without categories")
        end
      else
        Rails.logger.info("AI categorization disabled for statement #{@statement_file.id}")
      end

      # Step 4: Restore PII (before import)
      restore_result = restore_pii(processed_data)
      return handle_failure("PII restoration failed") unless restore_result.success?

      final_data = restore_result.payload

      # Step 5: Import transactions (handles duplicates) - Importer uses its own transaction
      import_result = import_transactions(final_data)
      return handle_failure("Transaction import failed") unless import_result.success?

      # Step 6: Update status based on duplicates
      status_result = update_status(import_result.payload)
      return handle_failure("Status update failed") unless status_result.success?

      # Step 7: Create financial summaries
      create_financial_summaries(final_data)

      # Step 8: Store final processed data
      @statement_file.update!(
        parsed_json: final_data,
        processed_at: Time.current
      )

      Rails.logger.info("Successfully processed statement #{@statement_file.id}")
      success(@statement_file)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      handle_failure("Database error: #{e.message}")
    rescue StandardError => e
      handle_failure("Processing failed: #{e.message}")
    end

    private

    attr_reader :statement_file

    def extract_with_vision
      Rails.logger.info("Step 1: Extracting transactions with Vision API")
      Statements::VisionExtractor.call(@statement_file)
    end

    def redact_pii(data)
      Rails.logger.info("Step 2: Redacting PII from #{data[:transactions]&.size || 0} transactions")
      Statements::PiiHandler.new(@statement_file, data).call
    end

    def categorize_transactions(data)
      Rails.logger.info("Step 3: Categorizing transactions with AI")
      Transactions::Categorizer.call(@statement_file, data)
    end

    def restore_pii(data)
      Rails.logger.info("Step 4: Restoring PII")
      Statements::PiiHandler.restore(@statement_file, data)
    end

    def import_transactions(data)
      transaction_count = data[:transactions]&.size || data["transactions"]&.size || 0
      Rails.logger.info("Step 5: Importing #{transaction_count} transactions")

      # Convert symbol keys to string keys for Importer
      json_data = if data.key?(:transactions)
        {
          "transactions" => data[:transactions],
          "financial_summaries" => data[:financial_summaries],
          "opening_balance" => data[:opening_balance],
          "closing_balance" => data[:closing_balance],
          "extraction_source" => data[:extraction_source]
        }
      else
        data
      end

      Transactions::Importer.new(@statement_file, json: json_data).call
    end

    def update_status(import_payload)
      Rails.logger.info("Step 6: Updating statement status")
      Statements::StatusManager.call(@statement_file, import_payload)
    end

    def create_financial_summaries(data)
      Rails.logger.info("Step 7: Creating financial summaries")

      summaries = data[:financial_summaries] || data["financial_summaries"]
      return unless summaries&.any?

      summaries.each do |summary_data|
        statement_type = determine_statement_type
        FinancialSummaryService.new(@statement_file).create_financial_summary(summary_data, statement_type)
      end
    end

    def determine_statement_type
      case @statement_file.bank_account.account_type
      when "credit"
        "credit"
      when "debit"
        "savings"
      when "checking"
        "checking"
      else
        "savings" # Default fallback
      end
    end

    def handle_failure(message)
      log_error(
        StandardError.new(message),
        context: "Statement processing",
        data: context_for_logging
      )

      @statement_file.update(
        status: :error,
        error_message: message,
        processed_at: Time.current
      )

      errors.add(:base, message)
      failure
    end

    def context_for_logging
      {
        statement_file_id: @statement_file.id,
        bank_account: @statement_file.bank_account&.bank_name,
        user_id: @statement_file.user_id,
        ai_enabled: @statement_file.ai_enabled?
      }
    end
  end
end
