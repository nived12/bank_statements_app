# app/services/statement_parser_service.rb
class StatementParserService < ApplicationService
  include ParsingStrategies
  include Configurable
  def self.parse(statement, text_chunks, masked_text, text, ai_enabled: true)
    new(statement).parse(text_chunks, masked_text, text, ai_enabled: ai_enabled)
  end

  def initialize(statement)
    super()
    @statement = statement
    @bank_account = statement.bank_account
  end

  def call
    # This service can be called directly, but the main method is parse
    success
  end

  def parse(text_chunks, masked_text, text, ai_enabled: true)
    return success(parse_with_parser_only(text)) unless ai_enabled

    strategy = bank_account.parsing_strategy
    Rails.logger.info("Using #{strategy} parsing strategy")

    result = case strategy
    when :hybrid
      parse_hybrid(text_chunks, masked_text, text)
    when :ai_first
      parse_ai_first(text_chunks, masked_text, text)
    when :parser_first
      parse_parser_first(text_chunks, masked_text, text)
    else
      parse_generic(text_chunks, masked_text, text)
    end

    if result&.dig("transactions")&.any?
      success(result)
    else
      errors.add(:base, :no_transactions_found, message: "No transactions found with #{strategy} strategy")
      failure
    end
  rescue => e
    errors.add(:base, :parsing_failed, message: e.message)
    Rails.logger.error("Statement parsing failed: #{e.message}")
    failure
  end

  def parse_with_deterministic_parser(text)
    # Use the appropriate parser based on bank account type
    parser = select_parser_for_bank
    parser.parse(text)
  rescue => e
    Rails.logger.error("Deterministic parser failed: #{e.message}")
    errors.add(:base, :deterministic_parser_failed, message: e.message)
    # Fall back to generic parser when the specific parser fails
    parse_with_generic_parser(text)
  end

  def parse_with_ai(text_chunks, masked_text)
    return nil unless ai_api_available?

    if text_chunks.length > 1
      process_multiple_chunks(text_chunks, Current.user.categories, masked_text)
    else
      process_single_chunk(masked_text)
    end
  rescue => e
    Rails.logger.error("AI parsing failed: #{e.message}")
    errors.add(:base, :ai_parsing_failed, message: e.message)
    nil
  end

  def parse_with_ai_enhancement(parser_result)
    # Use AI to enhance existing parser results with better categorization
    return nil unless ai_api_available?

    # Process each transaction individually for better AI categorization
    enhanced_transactions = []
    successful_enhancements = 0

    parser_result["transactions"].each_with_index do |txn, index|
      enhanced_text = "#{index + 1}. #{txn['description']} #{txn['amount']}"

      result = Ai::PostProcessor.call(
        raw_text: enhanced_text,
        bank_name: bank_account.bank_name,
        account_number: bank_account.account_number,
        categories: Current.user.categories
      )

      if result.success? && result.payload&.dig("transactions")&.any?
        # Use the first transaction from the AI result
        ai_txn = result.payload["transactions"].first
        enhanced_txn = merge_transaction_data(txn, ai_txn)
        enhanced_transactions << enhanced_txn
        successful_enhancements += 1
      else
        # If AI fails for this transaction, keep the original
        enhanced_transactions << txn
      end
    end

    # Return nil if no transactions were successfully enhanced
    return nil if successful_enhancements == 0

    {
      "transactions" => enhanced_transactions,
      "extraction_source" => "ai_enhanced_parser"
    }
  rescue => e
    Rails.logger.error("AI enhancement failed: #{e.message}")
    errors.add(:base, :ai_enhancement_failed, message: e.message)
    nil
  end

  def merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
    return parser_result unless ai_result&.dig("transactions")&.any?

    # Create a lookup for AI transactions by unique ID
    ai_lookup = {}
    ai_result["transactions"].each do |ai_txn|
      ai_lookup[ai_txn["id"]] = ai_txn if ai_txn["id"]&.start_with?("TX_")
    end

    # Merge AI categorization into parser transactions
    merged_transactions = parser_result["transactions"].map.with_index do |parser_txn, index|
      unique_id = "TX_#{index}"
      ai_txn = ai_lookup[unique_id]

      if ai_txn
        merge_transaction_data(parser_txn, ai_txn)
      else
        parser_txn
      end
    end

    parser_result.merge(
      "transactions" => merged_transactions,
      "ai_enhancement" => true
    )
  end

  private

  attr_reader :statement, :bank_account

  def process_multiple_chunks(text_chunks, user_categories, masked_text)
    results = text_chunks.map { |chunk| process_single_chunk(chunk) }

    # Merge results from all chunks
    {
      "opening_balance" => results.first&.dig("opening_balance"),
      "closing_balance" => results.last&.dig("closing_balance"),
      "transactions" => results.flat_map { |r| r["transactions"] || [] }
    }
  end

  def process_single_chunk(text)
    result = Ai::PostProcessor.call(
      raw_text: text,
      bank_name: bank_account.bank_name,
      account_number: bank_account.account_number,
      categories: Current.user.categories
    )

    result.success? ? result.payload : nil
  end

  def merge_transaction_data(parser_txn, ai_txn)
    merged = parser_txn.dup

    # Merge AI categorization while keeping parser core data
    merged["merchant"] = ai_txn["merchant"] if ai_txn["merchant"].present?
    merged["category"] = ai_txn["category"] if ai_txn["category"].present?
    merged["subcategory"] = ai_txn["subcategory"] if ai_txn["subcategory"].present?

    merged
  end

  def select_parser_for_bank
    parser_class = bank_account.parser_class if bank_account.respond_to?(:parser_class)

    if parser_class
      parser_class.new
    else
      # Fallback to parser_type-based selection
      case bank_account.parser_type
      when "bbva"
        if bank_account.account_type == "credit"
          PdfParser::NewBbvaCreditCard.new
        else
          PdfParser::NewBbvaSavingsAccount.new
        end
      when "santander"
        PdfParser::Generic.new
      when "banorte"
        PdfParser::Generic.new
      when "banamex"
        PdfParser::Generic.new
      else
        PdfParser::Generic.new
      end
    end
  end



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
    result = PdfParser::Generic.new.parse(text)
    if result
      result["extraction_source"] = "generic_parser"
    end
    result
  rescue => e
    Rails.logger.error("Generic parser failed: #{e.message}")
    nil
  end

  def determine_extraction_source(result, default_source)
    # Preserve OCR source if it was detected, otherwise use the default
    if result["extraction_source"] == "ocr"
      "ocr"
    else
      default_source
    end
  end

  def create_transaction_key(transaction)
    # Create a key for matching transactions between parser and AI results
    # Use date, amount, and a simplified description
    date = transaction["date"]
    amount = transaction["amount"].to_s
    description = transaction["description"].to_s.downcase.gsub(/[^a-z0-9]/, "") # Remove special chars

    # Normalize amount to handle string vs float differences
    normalized_amount = amount.to_f.abs.to_s # Use absolute value and convert to string

    # Create multiple key variations for better matching
    [
      "#{date}_#{normalized_amount}_#{description[0..20]}", # Exact match
      "#{date}_#{description[0..20]}" # Date + description only (ignore amount differences)
    ]
  end

  def process_ai_enhancement_batches(batches, user_categories)
    all_transactions = []

    batches.each_with_index do |batch, index|
      # Process each transaction individually within each batch
      batch.each do |description|
        result = Ai::PostProcessor.call(
          raw_text: description,
          bank_name: bank_account.bank_name,
          account_number: bank_account.account_number,
          categories: user_categories
        )

        if result.success? && result.payload&.dig("transactions")&.any?
          all_transactions.concat(result.payload["transactions"])
        end
      end
    end

    if all_transactions.any?
      {
        "transactions" => all_transactions,
        "extraction_source" => "ai_enhanced_parser"
      }
    else
      nil
    end
  end

  def create_transaction_batches(transaction_descriptions, batch_count)
    total = transaction_descriptions.count
    batch_size = (total.to_f / batch_count).ceil

    batches = []
    transaction_descriptions.each_slice(batch_size) do |batch|
      batches << batch
    end

    batches
  end
end
