# app/services/statement_parser_service.rb
require "timeout"

class StatementParserService < ApplicationService
  include Configurable
  include ParsingStrategies

  def initialize(statement, text_data = nil)
    super()
    @statement = statement
    @bank_account = statement.bank_account
    @text_data = text_data
    @ai_enabled = statement.ai_enabled?
    @user = statement.user
  end

  attr_reader :statement, :bank_account, :text_data, :ai_enabled, :user

  def self.call(statement, text_data = nil)
    new(statement, text_data).call
  end

  def call
    # For supported banks, use hybrid approach if AI enabled, otherwise deterministic parser only
    # For unsupported banks, this service is not called (handled by orchestrator)

    if ai_enabled
      # Use hybrid approach: deterministic parser + AI categorization
      parse_hybrid(text_data[:text_chunks], text_data[:text])
    else
      # Use deterministic parser only
      parse_parser_first(text_data[:text_chunks], text_data[:text])
    end
  rescue => e
    errors.add(:base, :parsing_failed, message: e.message)
    Rails.logger.error("Statement parsing failed: #{e.message}")
    failure
  end

  def parse_with_deterministic_parser(text)
    # Use the appropriate parser based on bank account type
    parser_class = bank_account.parser_class
    result = parser_class.call(text)

    if result.success?
      payload = result.payload
      # Set extraction_source if not already set by the parser
      if payload.is_a?(Hash) && payload["extraction_source"].blank?
        if parser_class == PdfParser::Generic
          payload["extraction_source"] = "generic_parser"
        else
          payload["extraction_source"] = "deterministic_parser"
        end
      end
      payload
    else
      Rails.logger.error("Deterministic parser failed: #{result.errors.full_messages.join(', ')}")
      errors.add(:base, :deterministic_parser_failed, message: result.errors.full_messages.join(", "))
      # Fall back to generic parser when the specific parser fails
      parse_with_generic_parser(text)
    end
  rescue => e
    Rails.logger.error("Deterministic parser failed: #{e.message}")
    errors.add(:base, :deterministic_parser_failed, message: e.message)
    # Fall back to generic parser when the specific parser fails
    parse_with_generic_parser(text)
  end

  private

  def context_for_logging
    {
      statement_id: statement.id,
      bank_account: bank_account&.bank_name,
      user_id: Current.user.id,
      parser_type: bank_account&.parser_type
    }
  end

  # Additional methods for backward compatibility with specs
  def parse_with_generic_parser(text)
    result = PdfParser::Generic.call(text)
    if result.success?
      payload = result.payload
      payload["extraction_source"] = "generic_parser"
      payload
    else
      Rails.logger.error("Generic parser failed: #{result.errors.full_messages.join(', ')}")
      nil
    end
  rescue => e
    Rails.logger.error("Generic parser failed: #{e.message}")
    nil
  end

  def parse_with_ai(text_chunks, text)
    # This method is used as a fallback in parse_hybrid when parser fails
    # Use AI PostProcessor for full parsing
    begin
      result = Ai::PostProcessor.call(
        statement_file: statement,
        raw_text: text,
        client: Ai::Client.new
      )

      if result.success?
        success(result.payload)
      else
        Rails.logger.error("AI parsing failed: #{result.errors.full_messages}")
        success(empty_result)
      end
    rescue => e
      Rails.logger.error("AI parsing processing failed: #{e.message}")
      success(empty_result)
    end
  end

  def parse_with_ai_enhancement(parser_result)
    # Use AI PostProcessor for transaction enhancement only
    begin
      transactions = parser_result["transactions"] || []
      return nil if transactions.empty?

      Rails.logger.info("Starting AI enhancement for #{transactions.length} transactions")

      # Process transactions in batches to avoid truncation
      batch_size = 25
      enhanced_transactions = []
      total_batches = (transactions.length.to_f / batch_size).ceil
      
      transactions.each_slice(batch_size).with_index do |batch, index|
        batch_number = index + 1
        Rails.logger.info("Processing AI batch #{batch_number}/#{total_batches}: #{batch.length} transactions")
        
        result = Ai::PostProcessor.call(
          statement_file: statement,
          transactions: batch,
          client: Ai::Client.new
        )

        if result.success?
          batch_enhanced = result.payload["transactions"] || []
          enhanced_transactions.concat(batch_enhanced)
          Rails.logger.info("Successfully enhanced #{batch_enhanced.length} transactions in batch #{batch_number}")
        else
          Rails.logger.error("AI categorization failed for batch #{batch_number}: #{result.errors.full_messages}")
          # Add original transactions if AI fails
          enhanced_transactions.concat(batch)
          Rails.logger.warn("Using original transactions for batch #{batch_number} due to AI failure")
        end
      end

      Rails.logger.info("AI enhancement completed: #{enhanced_transactions.length} total transactions processed")

      {
        "transactions" => enhanced_transactions,
        "extraction_source" => "ai_enhanced_parser"
      }
    rescue => e
      Rails.logger.error("AI categorization processing failed: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
      nil
    end
  end

  def merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
    # Create a map of AI transactions by description for quick lookup
    ai_transactions_map = {}
    ai_result["transactions"]&.each do |ai_transaction|
      # Use description as key for matching
      key = ai_transaction["description"]&.downcase&.strip
      ai_transactions_map[key] = ai_transaction if key.present?
    end

    # Enhance parser transactions with AI categorization
    enhanced_transactions = parser_result["transactions"]&.map do |parser_transaction|
      enhanced_transaction = parser_transaction.dup

      # Try to find matching AI transaction
      parser_description = parser_transaction["description"]&.downcase&.strip
      ai_transaction = ai_transactions_map[parser_description]

      if ai_transaction
        # Merge AI categorization data
        # Note: category and sub_category names are deleted by ResponseParser, only IDs remain
        enhanced_transaction["merchant"] = ai_transaction["merchant"] if ai_transaction["merchant"].present?
        enhanced_transaction["transaction_type"] = ai_transaction["transaction_type"] if ai_transaction["transaction_type"].present?
        
        # Merge AI categorization IDs and confidence scores
        enhanced_transaction["category_id"] = ai_transaction["category_id"] if ai_transaction["category_id"].present?
        enhanced_transaction["sub_category_id"] = ai_transaction["sub_category_id"] if ai_transaction["sub_category_id"].present?
        enhanced_transaction["confidence"] = ai_transaction["confidence"] if ai_transaction["confidence"].present?
        enhanced_transaction["category_confidence"] = ai_transaction["category_confidence"] if ai_transaction["category_confidence"].present?
        enhanced_transaction["transaction_type_confidence"] = ai_transaction["transaction_type_confidence"] if ai_transaction["transaction_type_confidence"].present?
        
        # Note: bank_entry_type is already correct from the parser
      end

      enhanced_transaction
    end

    # Return enhanced result
    {
      "transactions" => enhanced_transactions || [],
      "financial_summaries" => parser_result["financial_summaries"] || [],
      "raw_text" => parser_result["raw_text"],
      "opening_balance" => parser_result["opening_balance"],
      "closing_balance" => parser_result["closing_balance"],
      "extraction_source" => "ai_enhanced_parser"
    }
  end
end
