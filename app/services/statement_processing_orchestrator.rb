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
    statement.update(status: "processing")
    temp_file = create_temp_file(statement)

    begin
      # Extract and process text in one consolidated step
      text_data = extract_and_process_text(temp_file.path, statement)
      return false unless text_data

      # Parse statement with simplified logic
      parsed = parse_statement(text_data)
      return false unless parsed

      parsed = restore_pii_tokens(parsed, statement)

      # Finalize processing
      finalize_processing(parsed, text_data)

      true
    rescue => e
      log_error(e, context: "Statement processing", data: { statement_id: statement.id })
      statement.update(
        status: "error",
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

    def parse_with_santander_parser(text_data)
      begin
        require_relative "../pdf_parser/santander_savings_account"
        parser = PdfParser::SantanderSavingsAccount.new(text_data[:text])
        result = parser.call

        if result.success? && result.payload["transactions"].any?
          # Convert parser result to the expected format
          transactions = result.payload["transactions"].map do |txn|
            {
              "date" => txn["date"],
              "description" => txn["description"],
              "amount" => txn["amount"],
              "transaction_type" => txn["transaction_type"],
              "bank_entry_type" => txn["bank_entry_type"],
              "reference" => txn["reference"],
              "raw_text" => txn["description"],
              "confidence" => 0.9,
              "category_confidence" => 0.8,
              "transaction_type_confidence" => 0.9
            }
          end

          {
            "transactions" => transactions,
            "financial_summaries" => result.payload["financial_summaries"],
            "extraction_source" => "santander_parser"
          }
        else
          { "transactions" => [], "financial_summaries" => [] }
        end
      rescue => e
        log_error(e, context: "Santander parser", data: { statement_id: statement.id })
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
    end

    # Create financial summaries
    create_financial_summaries(text_data[:financial_data], parsed)

    # Update statement status
    statement.update(
      parsed_json: parsed,
      status: "parsed",
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
