# app/services/statement_parser_service.rb
class StatementParserService
  def initialize(statement)
    @statement = statement
    @bank_account = statement.bank_account
    @user = statement.user
    @source = nil
  end

  def parse(text_chunks, masked_text, text)
    # Determine the best parsing strategy based on bank configuration
    strategy = bank_account.parsing_strategy

    case strategy
    when :hybrid
      parse_with_hybrid_approach(text_chunks, masked_text, text)
    when :ai_first
      parse_with_ai_or_fallback(text_chunks, masked_text, text)
    when :parser_first
      parse_with_parser_or_fallback(text_chunks, masked_text, text)
    else
      parse_with_generic_fallback(text_chunks, masked_text, text)
    end
  end

  private

  attr_reader :statement, :bank_account, :user

  def parse_with_hybrid_approach(text_chunks, masked_text, text)
    # Step 1: Try deterministic parser first
    parser_result = parse_with_deterministic_parser(text)

    if parser_result&.dig("transactions")&.any?
      # Parser successful, now try AI for better categorization
      ai_result = parse_with_ai(text_chunks, masked_text)

      if ai_result&.dig("transactions")&.any?
        # AI parsing successful, merge with parser data
        merged_result = merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
        merged_result["extraction_source"] = determine_extraction_source(parser_result, "ai_enhanced_parser")
        merged_result
      else
        # AI parsing failed, use parser result with basic categorization
        parser_result["extraction_source"] = determine_extraction_source(parser_result, "parser_with_basic_categorization")
        parser_result
      end
    else
      Rails.logger.warn("Deterministic parser failed, falling back to AI only")
      # Fallback to AI if parser completely fails
      ai_result = parse_with_ai(text_chunks, masked_text)

      if ai_result&.dig("transactions")&.any?
        ai_result["extraction_source"] = "ai_parser_fallback"
        ai_result
      else
        Rails.logger.error("Both deterministic parser and AI failed")
        { "transactions" => [], "financial_summaries" => [] }
      end
    end
  end

  def parse_with_ai_or_fallback(text_chunks, masked_text, text)
    ai_result = parse_with_ai(text_chunks, masked_text)

    if ai_result.nil?
      # AI parse returned nil, using fallback parser
      fallback_result = parse_with_deterministic_parser(text)

      if fallback_result&.dig("transactions")&.any?
        fallback_result
      else
        Rails.logger.warn("Fallback parser also failed or returned no transactions")
        fallback_result || { "transactions" => [], "financial_summaries" => [] }
      end
    else
      # AI parse returned result, using AI result
      ai_result
    end
  end

  def parse_with_parser_or_fallback(text_chunks, masked_text, text)
    parser_result = parse_with_deterministic_parser(text)

    if parser_result&.dig("transactions")&.any?
      parser_result
    else
      # Parser failed, try AI as fallback
      ai_result = parse_with_ai(text_chunks, masked_text)

      if ai_result&.dig("transactions")&.any?
        ai_result["extraction_source"] = "ai_parser_fallback"
        ai_result
      else
        Rails.logger.warn("Both parser and AI failed")
        { "transactions" => [], "financial_summaries" => [] }
      end
    end
  end

  def parse_with_generic_fallback(text_chunks, masked_text, text)
    # Try AI first, then generic parser
    ai_result = parse_with_ai(text_chunks, masked_text)

    if ai_result&.dig("transactions")&.any?
      ai_result
    else
      generic_result = parse_with_generic_parser(text)
      generic_result || { "transactions" => [], "financial_summaries" => [] }
    end
  end

  def parse_with_deterministic_parser(text)
    parser_type = bank_account.parser_type
    parser_class = bank_account.parser_class

    result = parser_class.new.parse(text, context: {})

    if result
      result["extraction_source"] = determine_extraction_source(result, "#{parser_type}_parser")
    end

    result
  rescue => e
    Rails.logger.error("Deterministic parser failed: #{e.message}, using generic parser")
    parse_with_generic_parser(text)
  end

  def parse_with_generic_parser(text)
    result = PdfParser::Generic.new.parse(text, context: {})

    if result
      result["extraction_source"] = determine_extraction_source(result, "generic_parser")
    end

    result
  end

  def parse_with_ai(text_chunks, masked_text)
    return nil unless ConfigurationService.ai_api_available?

    user_categories = user.categories

    # Add retry logic for AI API failures
    max_retries = ConfigurationService.ai_max_retries
    retry_count = 0

    begin
      if text_chunks.length > 1
        result = process_multiple_chunks(text_chunks, user_categories, masked_text)

        if result && result["transactions"]&.any?
          result
        else
          Rails.logger.warn("AI parsing returned no transactions, falling back to deterministic parser")
          nil
        end
      else
        result = Ai::PostProcessor.new.call(
          raw_text: masked_text,
          bank_name: bank_account.bank_name,
          account_number: bank_account.account_number,
          categories: user_categories
        )

        if result && result["transactions"]&.any?
          result
        else
          Rails.logger.warn("AI parsing returned no transactions, falling back to deterministic parser")
          nil
        end
      end
    rescue => e
      retry_count += 1
      if retry_count <= max_retries
        delay = ConfigurationService.ai_retry_delay_base ** retry_count
        Rails.logger.warn("AI parsing failed (attempt #{retry_count}/#{max_retries}): #{e.message}. Retrying in #{delay}s...")
        sleep(delay)
        retry
      else
        Rails.logger.error("AI parsing failed after #{max_retries} attempts: #{e.message}")
        nil
      end
    end
  end

  def process_multiple_chunks(text_chunks, user_categories, masked_text)
    # Process multiple chunks and merge results
    results = []

    text_chunks.each_with_index do |chunk, index|
      # Process the chunk
      result = Ai::PostProcessor.new.call(
        raw_text: chunk,
        bank_name: bank_account.bank_name,
        account_number: bank_account.account_number,
        categories: user_categories
      )

      if result && result["transactions"]
        results << result
      end
    end

    # Merge all results
    merged = {
      "opening_balance" => results.first&.dig("opening_balance"),
      "closing_balance" => results.last&.dig("closing_balance"),
      "transactions" => results.flat_map { |r| r["transactions"] || [] }
    }

    merged
  end

  def merge_ai_categorization_with_parser_transactions(parser_result, ai_result)
    # Create a lookup map for AI transactions by key fields
    ai_lookup = {}
    ai_result["transactions"].each do |ai_txn|
      # Create multiple key variations for better matching
      keys = create_transaction_key(ai_txn)
      keys.each do |key|
        ai_lookup[key] = ai_txn
      end
    end

    # Merge AI categorization into parser transactions
    merged_transactions = parser_result["transactions"].map do |parser_txn|
      # Try to find matching AI transaction using multiple key variations
      parser_keys = create_transaction_key(parser_txn)
      ai_txn = nil

      # Try each key variation until we find a match
      parser_keys.each do |key|
        if ai_lookup[key]
          ai_txn = ai_lookup[key]
          break
        end
      end

      if ai_txn
        # Merge AI categorization while keeping parser core data
        merged_txn = parser_txn.dup
        merged_txn["merchant"] = ai_txn["merchant"] if ai_txn["merchant"].present?
        merged_txn["category"] = ai_txn["category"] if ai_txn["category"].present?
        merged_txn["sub_category"] = ai_txn["sub_category"] if ai_txn["sub_category"].present?
        merged_txn["reference"] = ai_txn["reference"] if ai_txn["reference"].present?
        merged_txn["confidence"] = ai_txn["confidence"] if ai_txn["confidence"].present?
        merged_txn["category_confidence"] = ai_txn["category_confidence"] if ai_txn["category_confidence"].present?
        merged_txn["transaction_type_confidence"] = ai_txn["transaction_type_confidence"] if ai_txn["transaction_type_confidence"].present?

        merged_txn
      else
        # No AI match found, keep parser transaction as is
        parser_txn
      end
    end

    # Return merged result
    {
      "opening_balance" => parser_result["opening_balance"],
      "closing_balance" => parser_result["closing_balance"],
      "transactions" => merged_transactions,
      "financial_summaries" => parser_result["financial_summaries"] || []
    }
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

  def determine_extraction_source(result, default_source)
    # Preserve OCR source if it was detected, otherwise use the default
    if result["extraction_source"] == "ocr"
      "ocr"
    else
      default_source
    end
  end
end
