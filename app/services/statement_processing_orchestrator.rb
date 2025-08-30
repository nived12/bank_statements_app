# app/services/statement_processing_orchestrator.rb
class StatementProcessingOrchestrator < ApplicationService
  include TextProcessable
  include TextFilteringPatterns
  include PiiTokenManageable
  include Configurable
  include ErrorHandling
  include FileHandling

  def self.process(statement_file_id)
    call(statement_file_id)
  end

  def initialize(statement_file_id)
    @statement = StatementFile.find(statement_file_id)
  end

  def call
    return failure unless process_statement

    success(statement)
  end

  def parse_with_deterministic_parser(text)
    # Use the existing parser service but simplified
    result = StatementParserService.new(statement).parse_with_deterministic_parser(text)
    result
  end

  def parse_with_ai(text_chunks, masked_text)
    # Use the existing AI service but simplified
    result = StatementParserService.new(statement).parse(text_chunks, masked_text, text_chunks.join("\n"), ai_enabled: true)
    result.success? ? result.payload : nil
  end

  def parse_with_ai_enhancement(parser_result)
    # Use the existing AI enhancement service but simplified
    result = StatementParserService.new(statement).parse_with_ai_enhancement(parser_result)
    result
  end

  def merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
    # Use the existing merge logic but simplified
    result = StatementParserService.new(statement).merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
    result
  end

  private

  attr_reader :statement

  def process_statement
    statement.update(status: "processing")
    temp_file = create_temp_file(statement)

    begin
      # Extract and process text in one consolidated step
      text_data = extract_and_process_text(temp_file.path, statement)
      return false unless text_data

      # Parse statement with simplified logic
      parsed = parse_statement_simplified(text_data)
      return false unless parsed

      # Restore PII if needed
      if pii_redaction_enabled?
        parsed = restore_pii_tokens(parsed, statement)
      end

      # Finalize processing
      finalize_processing(parsed, text_data)

      true
    rescue => e
      handle_statement_error(statement, e)
      errors.add(:base, :processing_failed, message: e.message)
      false
    ensure
      cleanup_temp_file(temp_file)
    end
  end



  def parse_statement_simplified(text_data)
    ai_enabled = statement.ai_enabled?
    strategy = statement.bank_account.parsing_strategy

    Rails.logger.info("Processing statement with AI #{ai_enabled ? 'enabled' : 'disabled'} using #{strategy} strategy")

    # Simplified parsing logic that handles all strategies in one place
    result = case strategy
    when :hybrid
      parse_hybrid_simplified(text_data, ai_enabled)
    when :ai_first
      parse_ai_first_simplified(text_data, ai_enabled)
    when :parser_first
      parse_parser_first_simplified(text_data, ai_enabled)
    else
      parse_generic_simplified(text_data, ai_enabled)
    end

    result || { "transactions" => [], "financial_summaries" => [] }
  end

  def parse_hybrid_simplified(text_data, ai_enabled)
    # Try parser first, then enhance with AI if available
    parser_result = parse_with_deterministic_parser(text_data[:text])

    if parser_result&.dig("transactions")&.any?
      # Parser succeeded, try to enhance with AI
      if ai_enabled && ai_api_available?
        ai_result = parse_with_ai_enhancement(parser_result)
        ai_result&.dig("transactions")&.any? ?
          merge_ai_categorization_with_parser_transactions(parser_result, ai_result) :
          parser_result
      else
        parser_result
      end
    else
      # Parser failed, try AI fallback
      ai_enabled && ai_api_available? ?
        parse_with_ai(text_data[:text_chunks], text_data[:filtered_text]) :
        nil
    end
  end

  def parse_ai_first_simplified(text_data, ai_enabled)
    if ai_enabled && ai_api_available?
      ai_result = parse_with_ai(text_data[:text_chunks], text_data[:filtered_text])
      ai_result || parse_with_deterministic_parser(text_data[:text])
    else
      parse_with_deterministic_parser(text_data[:text])
    end
  end

  def parse_parser_first_simplified(text_data, ai_enabled)
    parser_result = parse_with_deterministic_parser(text_data[:text])

    if parser_result&.dig("transactions")&.any?
      parser_result
    elsif ai_enabled && ai_api_available?
      parse_with_ai(text_data[:text_chunks], text_data[:filtered_text])
    else
      nil
    end
  end

  def parse_generic_simplified(text_data, ai_enabled)
    if ai_enabled && ai_api_available?
      parse_with_ai(text_data[:text_chunks], text_data[:filtered_text])
    else
      parse_with_deterministic_parser(text_data[:text])
    end
  end



  def finalize_processing(parsed, text_data)
    # Annotate parsed data
    if parsed.is_a?(Hash) && parsed["extraction_source"].blank?
      parsed["extraction_source"] = text_data[:source]
    end

    # Import transactions
    if parsed["transactions"]
      Transactions::Importer.call(statement, json: parsed)
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
    # Create financial summaries using the service
    if financial_data.present?
      FinancialSummaryService.new(statement).create_from_extracted_data(financial_data)
    end

    # Create financial summaries from parsed data if available
    if parsed["financial_summaries"]&.any?
      FinancialSummaryService.new(statement).create_from_parsed_data(parsed)
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
