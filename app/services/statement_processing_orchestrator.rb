# app/services/statement_processing_orchestrator.rb
class StatementProcessingOrchestrator
  def self.process(statement_file_id)
    statement = StatementFile.find(statement_file_id)
    statement.update(status: "processing")

    new(statement).process
  end

  def initialize(statement)
    @statement = statement
    @text_processing_service = TextProcessingService.new(statement)
    @financial_summary_service = FinancialSummaryService.new(statement)
  end

  def process
    temp_file = FileHandlingService.create_temp_file(statement)

    begin
      # Extract and process text
      text = text_processing_service.extract_text(temp_file.path)
      return false unless text

      # Extract financial data and process text
      financial_data = text_processing_service.extract_financial_data(text)
      masked_text = apply_pii_redaction(text)
      filtered_text = text_processing_service.filter_text(masked_text)
      text_chunks = text_processing_service.prepare_text_chunks(filtered_text)

      # Parse with bank-agnostic approach
      parsed = parse_statement(text_chunks, masked_text, text)

      # Restore PII and finalize
      if ConfigurationService.pii_redaction_enabled?
        parsed = restore_pii_tokens(parsed)
      end

      annotate_parsed_data(parsed, text_processing_service.source)
      import_transactions(parsed)

      # Create financial summaries
      create_financial_summaries(financial_data, parsed)

      # Update statement status
      statement.update(
        parsed_json: parsed,
        status: "parsed",
        processed_at: Time.current
      )

      true
    rescue => e
      ErrorHandlingService.handle_statement_error(statement, e)
      false
    ensure
      FileHandlingService.cleanup_temp_file(temp_file)
    end
  end

  private

  attr_reader :statement, :text_processing_service, :financial_summary_service

  def parse_statement(text_chunks, masked_text, text)
    ai_enabled = statement.ai_enabled?
    if ai_enabled
      Rails.logger.info("Processing statement with AI enabled")
    else
      Rails.logger.info("Processing statement with AI disabled - using parser-only approach")
    end

    parser_service = StatementParserService.new(statement)
    parser_service.parse(text_chunks, masked_text, text, ai_enabled: ai_enabled)
  end

  def apply_pii_redaction(text)
    return text unless ConfigurationService.pii_redaction_enabled?

    redacted, map, hmac = PiiRedactor.new.redact_preserving_transactions(text)

    # Ensure the redaction_map is properly set
    if map.present?
      statement.update!(redaction_map: map, redaction_hmac: hmac)
    else
      # If no PII was found, set empty map but still set the fields
      statement.update!(redaction_map: {}, redaction_hmac: hmac)
    end

    redacted
  rescue => e
    ErrorHandlingService.handle_pii_error(statement, e)
    raise
  end

  def restore_pii_tokens(parsed)
    return parsed unless statement.redaction_hmac.present? && statement.redaction_map.present?

    Rails.logger.info("[PII] Restoring tokens from map: #{statement.redaction_map.inspect}")
    restored = restore_tokens_deep(parsed, statement.redaction_map)
    Rails.logger.info("[PII] Token restoration completed")
    restored
  rescue => e
    Rails.logger.error("[PII] Token restoration error: #{e.message}")
    raise RuntimeError, "PII token restoration failed: #{e.message}"
  end

  def restore_tokens_deep(obj, map)
    case obj
    when Hash
      obj.transform_values { |v| restore_tokens_deep(v, map) }
    when Array
      obj.map { |v| restore_tokens_deep(v, map) }
    when String
      # Replace tokens within the string, not the entire string
      result = obj.dup
      map.each { |token, original| result.gsub!(token, original.to_s) }
      result
    else
      obj
    end
  end

  def annotate_parsed_data(parsed, source)
    return unless parsed.is_a?(Hash)

    # Only set extraction_source if it's not already set by a parser
    # This allows parsers to set their own extraction_source
    if parsed["extraction_source"].blank?
      parsed["extraction_source"] = source
    end
  end

  def import_transactions(parsed)
    return unless parsed["transactions"]

    # Use the existing transaction importer service
    Transactions::Importer.call(statement, json: parsed)
  end

  def create_financial_summaries(financial_data, parsed)
    # Create financial summaries using the service
    if financial_data.present?
      financial_summary_service.create_from_extracted_data(financial_data)
    end

    # Create financial summaries from parsed data if available
    if parsed["financial_summaries"]&.any?
      financial_summary_service.create_from_parsed_data(parsed)
    end
  end
end
