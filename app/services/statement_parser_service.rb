# app/services/statement_parser_service.rb
class StatementParserService
  def initialize(statement)
    @statement = statement
    @bank_account = statement.bank_account
    @user = statement.user
    @source = nil
  end

  def parse(text_chunks, masked_text, text, ai_enabled: true)
    # If AI is disabled, force parser-first approach and skip all AI processing
    unless ai_enabled
      Rails.logger.info("AI processing disabled, using parser-only approach")
      return parse_with_parser_only(text)
    end

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
      # Parser successful, now try AI for better categorization if available
      if ConfigurationService.ai_api_available?
        ai_result = parse_with_ai_enhancement(parser_result)

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
        # AI not available, use parser result with basic categorization
        parser_result["extraction_source"] = determine_extraction_source(parser_result, "parser_with_basic_categorization")
        parser_result
      end
    else
      # Fallback to AI if parser completely fails and AI is available
      if ConfigurationService.ai_api_available?
        ai_result = parse_with_ai(text_chunks, masked_text)

        if ai_result&.dig("transactions")&.any?
          ai_result["extraction_source"] = "ai_parser_fallback"
          ai_result
        else
          Rails.logger.error("Both deterministic parser and AI failed")
          { "transactions" => [], "financial_summaries" => [] }
        end
      else
        Rails.logger.error("Deterministic parser failed and AI is not available")
        { "transactions" => [], "financial_summaries" => [] }
      end
    end
  end

  def parse_with_ai_or_fallback(text_chunks, masked_text, text)
    if ConfigurationService.ai_api_available?
      ai_result = parse_with_ai(text_chunks, masked_text)

      if ai_result.nil?
        # AI parse returned nil, using fallback parser
        fallback_result = parse_with_deterministic_parser(text)

        if fallback_result&.dig("transactions")&.any?
          fallback_result
        else
          fallback_result || { "transactions" => [], "financial_summaries" => [] }
        end
      else
        # AI parse returned result, using AI result
        ai_result
      end
    else
      # AI not available, use parser directly
      fallback_result = parse_with_deterministic_parser(text)
      fallback_result || { "transactions" => [], "financial_summaries" => [] }
    end
  end

  def parse_with_parser_or_fallback(text_chunks, masked_text, text)
    parser_result = parse_with_deterministic_parser(text)

    if parser_result&.dig("transactions")&.any?
      parser_result
    else
      # Parser failed, try AI as fallback only if AI is enabled
      if ConfigurationService.ai_api_available?
        ai_result = parse_with_ai(text_chunks, masked_text)

        if ai_result&.dig("transactions")&.any?
          ai_result["extraction_source"] = "ai_parser_fallback"
          ai_result
        else
          Rails.logger.warn("Both parser and AI failed")
          { "transactions" => [], "financial_summaries" => [] }
        end
      else
        Rails.logger.warn("Parser failed and AI is not available")
        { "transactions" => [], "financial_summaries" => [] }
      end
    end
  end

  def parse_with_generic_fallback(text_chunks, masked_text, text)
    # Try AI first, then generic parser
    if ConfigurationService.ai_api_available?
      ai_result = parse_with_ai(text_chunks, masked_text)

      if ai_result&.dig("transactions")&.any?
        ai_result
      else
        generic_result = parse_with_generic_parser(text)
        generic_result || { "transactions" => [], "financial_summaries" => [] }
      end
    else
      # AI not available, use generic parser directly
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

  def parse_with_ai_enhancement(parser_result)
    # AI enhancement for hybrid approach with smart batching strategy
    return nil unless ConfigurationService.ai_api_available?

    user_categories = user.categories
    transaction_descriptions = parser_result["transactions"].map { |t| t["description"] }
    total_transactions = transaction_descriptions.count

    # Smart batching strategy: 1 batch → 2 batches → 4 batches → give up
    batch_strategies = [
      { name: "single_batch", batch_count: 1 },
      { name: "two_batches", batch_count: 2 },
      { name: "four_batches", batch_count: 4 }
    ]

    batch_strategies.each_with_index do |strategy, attempt|
      begin
        result = attempt_ai_enhancement_with_batching(
          transaction_descriptions,
          strategy[:batch_count],
          user_categories
        )

        if result && result["transactions"]&.any?
          return result
        end

      rescue => e
        # Continue to next strategy on error
      end

      # Add delay between attempts (except for the last one)
      if attempt < batch_strategies.length - 1
        delay = ConfigurationService.ai_retry_delay_base ** (attempt + 1)
        sleep(delay)
      end
    end

    Rails.logger.error("AI enhancement: all batching strategies failed, giving up")
    nil
  end

  def attempt_ai_enhancement_with_batching(transaction_descriptions, batch_count, user_categories)
    if batch_count == 1
      # Process each transaction individually to avoid AI multi-line issues
      process_individual_transactions(transaction_descriptions, user_categories)
    else
      # Multiple batches - split transactions into batches
      batches = create_transaction_batches(transaction_descriptions, batch_count)

      process_ai_enhancement_batches(batches, user_categories)
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

    def process_individual_transactions(transaction_descriptions, user_categories)
    all_transactions = []

    transaction_descriptions.each_with_index do |description, index|
      # Add a unique ID to the description for matching
      unique_id = "TX_#{index}"
      enhanced_description = "[#{unique_id}] #{description}"

      result = Ai::PostProcessor.new.call(
        raw_text: enhanced_description,
        bank_name: bank_account.bank_name,
        account_number: bank_account.account_number,
        categories: user_categories
      )

      if result && result["transactions"]&.any?
        # Get the AI categorization result
        ai_txn = result["transactions"].first

        # Create a transaction with the AI categorization and the unique ID
        enhanced_txn = {
          "id" => unique_id,
          "description" => description, # Keep original description without ID
          "category" => ai_txn["category"],
          "sub_category" => ai_txn["sub_category"],
          "merchant" => ai_txn["merchant"],
          "transaction_type" => ai_txn["transaction_type"],
          "confidence" => ai_txn["confidence"],
          "category_confidence" => ai_txn["category_confidence"]
        }

        all_transactions << enhanced_txn
      end
    end

    if all_transactions.any?
      {
        "transactions" => all_transactions,
        "extraction_source" => "ai_enhanced_parser",
        "category_mapping" => build_category_mapping(user_categories)
      }
    else
      nil
    end
  end

  private

  def build_category_mapping(categories)
    # Build a category name to ID mapping for efficient lookup
    mapping = {}

    categories.each do |category|
      mapping[category.name] = category.id

      # Include subcategories if they exist
      category.children.each do |subcategory|
        mapping["#{category.name} > #{subcategory.name}"] = subcategory.id
      end
    end

    mapping
  end

  def process_ai_enhancement_batches(batches, user_categories)
    all_transactions = []

    batches.each_with_index do |batch, index|
      # Process each transaction individually within each batch
      batch.each do |description|
        result = Ai::PostProcessor.new.call(
          raw_text: description,
          bank_name: bank_account.bank_name,
          account_number: bank_account.account_number,
          categories: user_categories
        )

        if result && result["transactions"]&.any?
          all_transactions.concat(result["transactions"])
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
    # Detect which approach is being used by checking if AI transactions have unique IDs
    if ai_result["transactions"].any? { |t| t["id"]&.start_with?("TX_") }
      # Individual transaction processing - match by unique ID
      ai_lookup = {}
      ai_result["transactions"].each do |ai_txn|
        ai_lookup[ai_txn["id"]] = ai_txn
      end

      # Merge AI categorization into parser transactions
      merged_transactions = parser_result["transactions"].map.with_index do |parser_txn, index|
        unique_id = "TX_#{index}"
        ai_txn = ai_lookup[unique_id]

        if ai_txn
          # Merge AI categorization while keeping parser core data
          merged_txn = parser_txn.dup
          merged_txn["merchant"] = ai_txn["merchant"] if ai_txn["merchant"].present?

          # Convert category names to IDs using the mapping if available
          if ai_txn["category"].present?
            category_mapping = ai_result["category_mapping"] || {}
            if category_mapping.any?
              # New format: convert to ID
              merged_txn["category_id"] = category_mapping[ai_txn["category"]]
            else
              # Old format: preserve category name
              merged_txn["category"] = ai_txn["category"]
            end
          end

          if ai_txn["sub_category"].present?
            category_mapping = ai_result["category_mapping"] || {}
            if category_mapping.any?
              # New format: convert to ID
              merged_txn["sub_category_id"] = category_mapping[ai_txn["sub_category"]]
            else
              # Old format: preserve category name
              merged_txn["sub_category"] = ai_txn["sub_category"]
            end
          end

          merged_txn["reference"] = ai_txn["reference"] if ai_txn["reference"].present?
          merged_txn["confidence"] = ai_txn["confidence"] if ai_txn["confidence"].present?
          merged_txn["category_confidence"] = ai_txn["category_confidence"] if ai_txn["category_confidence"].present?
          merged_txn["transaction_type_confidence"] = ai_txn["transaction_type_confidence"] if ai_txn["transaction_type_confidence"].present?

          merged_txn
        else
          parser_txn
        end
      end
    else
      # Batch processing - match by date, amount, and description
      ai_lookup = {}
      ai_result["transactions"].each do |ai_txn|
        keys = create_transaction_key(ai_txn)
        keys.each do |key|
          ai_lookup[key] = ai_txn
        end
      end

      # Merge AI categorization into parser transactions
      merged_transactions = parser_result["transactions"].map do |parser_txn|
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

          # Convert category names to IDs using the mapping if available
          if ai_txn["category"].present?
            category_mapping = ai_result["category_mapping"] || {}
            if category_mapping.any?
              # New format: convert to ID
              merged_txn["category_id"] = category_mapping[ai_txn["category"]]
            else
              # Old format: preserve category name
              merged_txn["category"] = ai_txn["category"]
            end
          end

          if ai_txn["sub_category"].present?
            category_mapping = ai_result["category_mapping"] || {}
            if category_mapping.any?
              # New format: convert to ID
              merged_txn["sub_category_id"] = category_mapping[ai_txn["sub_category"]]
            else
              # Old format: preserve category name
              merged_txn["sub_category"] = ai_txn["sub_category"]
            end
          end

          merged_txn["reference"] = ai_txn["reference"] if ai_txn["reference"].present?
          merged_txn["confidence"] = ai_txn["confidence"] if ai_txn["confidence"].present?
          merged_txn["category_confidence"] = ai_txn["category_confidence"] if ai_txn["category_confidence"].present?
          merged_txn["transaction_type_confidence"] = ai_txn["transaction_type_confidence"] if ai_txn["transaction_type_confidence"].present?

          merged_txn
        else
          parser_txn
        end
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

  def parse_with_parser_only(text)
    # Simple parser-only approach without any AI fallbacks
    parser_result = parse_with_deterministic_parser(text)

    if parser_result&.dig("transactions")&.any?
      parser_result["extraction_source"] = "parser_only"
      parser_result
    else
      # Try generic parser as last resort
      generic_result = parse_with_generic_parser(text)
      if generic_result
        generic_result["extraction_source"] = "generic_parser_only"
        generic_result
      else
        { "transactions" => [], "financial_summaries" => [] }
      end
    end
  end
end
