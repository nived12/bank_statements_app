# app/services/statement_parser_service.rb
require "timeout"

class StatementParserService < ApplicationService
  include ParsingStrategies
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
    return success(parse_with_deterministic_parser(text_data[:text])) unless ai_enabled

    strategy = bank_account.parsing_strategy
    Rails.logger.info("Using #{strategy} parsing strategy")

    result = case strategy
    when :hybrid
      parse_hybrid(text_data[:text_chunks], text_data[:text])
    when :ai_first
      parse_ai_first(text_data[:text_chunks], text_data[:text])
    when :parser_first
      parse_parser_first(text_data[:text_chunks], text_data[:text])
    else
      parse_generic(text_data[:text_chunks], text_data[:text])
    end

    if result&.success? && result.payload&.dig("transactions")&.any?
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
    parser_class = bank_account.respond_to?(:parser_class) ? bank_account.parser_class : PdfParser::Generic
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

  def parse_with_ai(text_chunks, text)
    return unless ai_api_available?

    result = if text_chunks.length > 1
      process_multiple_chunks(text_chunks, user.categories, text)
    else
      process_single_chunk(text)
    end

    result
  rescue => e
    Rails.logger.error("AI parsing failed: #{e.message}")
    errors.add(:base, :ai_parsing_failed, message: e.message)
    nil
  end

  def parse_with_ai_enhancement(parser_result)
    # Use AI to enhance existing parser results with better categorization
    return unless ai_api_available?

    # Batch transactions for efficient AI processing (configurable batch size)
    transactions = parser_result["transactions"]
    return parser_result if transactions.empty?

    enhanced_transactions = []
    successful_enhancements = 0
    batch_size = ai_batch_size

    # Process transactions in batches to reduce API calls
    transactions.each_slice(batch_size) do |transaction_batch|
      # Create a single text with all transactions in the batch
      batch_text = transaction_batch.map.with_index do |txn, batch_index|
        global_index = enhanced_transactions.length + batch_index + 1
        "#{global_index}. #{txn['description']} #{txn['amount']}"
      end.join("\n")

      result = Ai::PostProcessor.new(
        raw_text: batch_text,
        bank_name: bank_account.bank_name,
        account_number: bank_account.account_number,
        categories: user.categories
      ).call

      if result.success? && result.payload&.dig("transactions")&.any?
        # Merge AI results with original transactions
        ai_transactions = result.payload["transactions"]
        transaction_batch.each_with_index do |original_txn, batch_index|
          ai_txn = ai_transactions[batch_index]
          if ai_txn
            enhanced_txn = merge_transaction_data(original_txn, ai_txn)
            enhanced_transactions << enhanced_txn
            successful_enhancements += 1
          else
            # If no AI result for this transaction, keep the original
            enhanced_transactions << original_txn
          end
        end
      else
        # If AI fails for this batch, keep all original transactions
        enhanced_transactions.concat(transaction_batch)
      end
    end

    # return if no transactions were successfully enhanced
    return if successful_enhancements == 0

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
    return parser_result unless ai_result&.success? && ai_result.payload&.dig("transactions")&.any?

    # Create a lookup for AI transactions by unique ID
    ai_lookup = {}
    ai_result.payload["transactions"].each do |ai_txn|
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


  def process_multiple_chunks(text_chunks, user_categories, text)
    Rails.logger.info("🚀 Processing #{text_chunks.length} chunks in parallel...")
    start_time = Time.current

    # Process all chunks in parallel using threads
    threads = text_chunks.map.with_index do |chunk, index|
      Thread.new do
        Rails.logger.info("Processing chunk #{index + 1}/#{text_chunks.length} (#{chunk.length} chars)")

        begin
          result = Timeout.timeout(120) do # Increased timeout for parallel processing
            process_single_chunk(chunk)
          end
          Rails.logger.info("✅ Chunk #{index + 1} processed successfully")
          [ index, result ]
        rescue Timeout::Error
          Rails.logger.error("⏰ Chunk #{index + 1} timed out after 120s")
          [ index, nil ]
        rescue => e
          Rails.logger.error("❌ Chunk #{index + 1} failed: #{e.message}")
          [ index, nil ]
        end
      end
    end

    # Wait for all threads to complete and collect results
    results = Array.new(text_chunks.length)
    threads.each do |thread|
      index, result = thread.value
      results[index] = result
    end

    end_time = Time.current
    duration = (end_time - start_time).round(2)
    Rails.logger.info("🏁 All chunks processed in #{duration}s")

    # Merge results from all chunks (filter out nil results)
    valid_results = results.compact
    payload = {
      "opening_balance" => valid_results.first&.payload&.dig("opening_balance"),
      "closing_balance" => valid_results.last&.payload&.dig("closing_balance"),
      "transactions" => valid_results.flat_map { |r| r.payload&.dig("transactions") || [] }
    }

    success(payload)
  end

  def process_single_chunk(text)
    result = Ai::PostProcessor.new(
      raw_text: text,
      bank_name: bank_account.bank_name,
      account_number: bank_account.account_number,
      categories: user.categories
    ).call

    result.success? ? result : failure
  end

  def merge_transaction_data(parser_txn, ai_txn)
    merged = parser_txn.dup

    # Merge AI categorization while keeping parser core data
    merged["merchant"] = ai_txn["merchant"] if ai_txn["merchant"].present?
    merged["category"] = ai_txn["category"] if ai_txn["category"].present?
    merged["sub_category"] = ai_txn["sub_category"] if ai_txn["sub_category"].present?

    # Only update transaction_type if AI provides it and it's more specific
    if ai_txn["transaction_type"].present? && ai_txn["transaction_type"] != "variable_expense"
      merged["transaction_type"] = ai_txn["transaction_type"]
    end

    # Add confidence scores if available
    merged["confidence"] = ai_txn["confidence"] if ai_txn["confidence"].present?
    merged["category_confidence"] = ai_txn["category_confidence"] if ai_txn["category_confidence"].present?
    merged["transaction_type_confidence"] = ai_txn["transaction_type_confidence"] if ai_txn["transaction_type_confidence"].present?

    merged
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
