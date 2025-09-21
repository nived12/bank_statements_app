# app/services/statement_parser_service.rb
require "timeout"

class StatementParserService < ApplicationService
  include Configurable

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
    # For supported banks, use deterministic parser
    # For unsupported banks, this service is not called (handled by orchestrator)
    result = parse_with_deterministic_parser(text_data[:text])

    if result.present? && result["transactions"]&.any?
      success(result)
    else
      errors.add(:base, :no_transactions_found, message: "No transactions found with deterministic parser")
      failure
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
end
