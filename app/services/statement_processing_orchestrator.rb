# app/services/statement_processing_orchestrator.rb
class StatementProcessingOrchestrator < ApplicationService
  include TextProcessable
  include PiiHandlingConcern
  include Configurable
  include ErrorHandling
  include FileHandling

  def initialize(statement_file_id)
    super()
    @statement = StatementFile.find(statement_file_id)
  end

  def call
    return failure unless process_statement

    success(statement)
  end

  private

  def process_statement
    statement.update(status: :processing)
    temp_file = create_temp_file(statement)

    begin
      # Always extract and process text first (includes PII protection)
      text_data = extract_and_process_text(temp_file.path, statement)
      return false unless text_data

      # Check if bank supports this account type
      if statement.supported_bank_account_type?
        # Supported bank: Use specific parser (with AI enhancement if enabled)
        parsed = parse_statement(text_data)
        return false unless parsed
      else
        # Unsupported bank: Use AI Page Processor with processed text
        Rails.logger.info("Bank #{statement.bank_account.bank.name} does not support #{statement.bank_account.account_type} accounts, using AI Page Processor")

        parsed = parse_with_ai_post_processor(text_data)
        return false unless parsed
      end

      # Restore PII tokens for both supported and unsupported banks
      parsed = restore_pii_tokens(parsed, statement)
      finalize_processing(parsed, text_data)

      true
    rescue => e
      log_error(e, context: "Statement processing", data: { statement_id: statement.id })
      statement.update(
        status: :error,
        processed_at: Time.current,
        error_message: "Statement processing failed: #{e.message}"
      )
      errors.add(:base, :processing_failed, message: e.message)
      false
    ensure
      cleanup_temp_file(temp_file)
    end
  end

    def parse_statement(text_data)
      result = StatementParserService.call(statement, text_data)

      if result.success?
        result.payload
      else
        log_error(
          StandardError.new("Statement parsing failed: #{result.errors.full_messages.join(', ')}"),
          context: "Statement parsing",
          data: { statement_id: statement.id, errors: result.errors.full_messages }
        )
        { "transactions" => [], "financial_summaries" => [] }
      end
    end

    def parse_with_ai_post_processor(text_data)
      begin
        result = Ai::PostProcessor.call(
          statement_file: statement,
          raw_text: text_data[:text],
          client: Ai::Client.new
        )

        if result.success?
          # Return the extracted data for the orchestrator to process
          result.payload
        else
          log_error(
            StandardError.new("AI Page Processor failed: #{result.errors.full_messages.join(', ')}"),
            context: "AI Page Processor",
            data: { statement_id: statement.id, errors: result.errors.full_messages }
          )
          { "transactions" => [], "financial_summaries" => [] }
        end
      rescue => e
        log_error(e, context: "AI Page Processor", data: { statement_id: statement.id })
        { "transactions" => [], "financial_summaries" => [] }
      end
    end


  attr_reader :statement

  def finalize_processing(parsed, text_data)
    # Annotate parsed data
    if parsed.is_a?(Hash) && parsed["extraction_source"].blank?
      parsed["extraction_source"] = text_data[:source]
    end

    # Import transactions
    if parsed["transactions"]
      importer = Transactions::Importer.new(statement, json: parsed)
      importer_result = importer.call
      unless importer_result.success?
        log_error(
          StandardError.new("Failed to import transactions"),
          context: "Transaction import",
          data: { statement_id: statement.id, errors: importer_result.errors.full_messages }
        )
        return failure
      end

      # Check if duplicates were found and set appropriate status
      if importer_result.payload[:duplicates_found]
        # Duplicates found, keep status as :parsed for user review
        statement.update(status: :parsed)
        Rails.logger.info("Duplicates found for statement #{statement.id}, keeping status as :parsed")
      else
        # No duplicates found, mark as completed
        statement.update(status: :completed)
        Rails.logger.info("No duplicates found for statement #{statement.id}, marked as :completed")
      end
    else
      # No transactions to import, mark as completed
      statement.update(status: :completed)
    end

    # Create financial summaries
    create_financial_summaries(text_data[:financial_data], parsed)

    # Update statement with parsed data and processed timestamp
    # Status was already set above based on duplicate detection
    statement.update(
      parsed_json: parsed,
      processed_at: Time.current
    )
  end

  def create_financial_summaries(financial_data, parsed)
    # Create financial summaries from parsed data if available
    if parsed["financial_summaries"]&.any?
      parsed["financial_summaries"].each do |summary_data|
        # Determine the statement type based on the account type
        statement_type = case statement.bank_account.account_type
        when "credit"
          "credit"
        when "debit"
          "savings"
        when "checking"
          "checking"
        else
          "savings"  # Default fallback
        end
        FinancialSummaryService.new(statement).create_financial_summary(summary_data, statement_type)
      end
    end
  end

  def context_for_logging
    {
      statement_id: statement.id,
      bank_account: statement.bank_account&.bank_name,
      user_id: statement.user_id
    }
  end
end
