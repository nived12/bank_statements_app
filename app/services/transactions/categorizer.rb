# app/services/transactions/categorizer.rb
module Transactions
  class Categorizer < ApplicationService
    include Ai::Concerns::PromptBuilder
    include Ai::Concerns::ResponseParser

    BATCH_SIZE = 25 # Process 25 transactions at a time to avoid API truncation
    MIN_CATEGORY_CONFIDENCE = 0.5 # Only apply categories with >= 50% confidence

    def initialize(statement_file, data)
      super()
      @statement_file = statement_file
      @data = data
      @user = statement_file.user
      @categories = statement_file.user.categories.to_a
      @ai_client = Ai::Client.new
      @total_categorization_usage = { prompt_token_count: 0, candidates_token_count: 0, total_token_count: 0 }
    end

    def call
      transactions = extract_transactions(@data)

      if transactions.empty?
        Rails.logger.info("No transactions to categorize")
        return success(@data)
      end

      Rails.logger.info("Categorizing #{transactions.size} transactions for statement #{@statement_file.id}")

      categorized_transactions = categorize_in_batches(transactions)

      # Log total categorization costs
      log_categorization_cost(@total_categorization_usage) if @total_categorization_usage[:total_token_count] > 0

      # Return data with categorized transactions
      result = @data.dup
      if @data.key?(:transactions)
        result[:transactions] = categorized_transactions
      elsif @data.key?("transactions")
        result["transactions"] = categorized_transactions
      end

      success(result)
    rescue StandardError => e
      log_error(e, context: "Transaction categorization failed", data: context_for_logging)
      # Return original data on failure (graceful degradation)
      Rails.logger.warn("Categorization failed, returning original transactions")
      success(@data)
    end

    private

    attr_reader :statement_file, :data, :user, :categories, :ai_client

    def extract_transactions(data)
      data[:transactions] || data["transactions"] || []
    end

    def categorize_in_batches(transactions)
      categorized = []
      total_batches = (transactions.size.to_f / BATCH_SIZE).ceil

      transactions.each_slice(BATCH_SIZE).with_index do |batch, index|
        batch_number = index + 1
        Rails.logger.info(
          "Processing categorization batch #{batch_number}/#{total_batches} (#{batch.size} transactions)"
        )

        begin
          categorized_batch = categorize_batch(batch)
          categorized.concat(categorized_batch)
          Rails.logger.info("Successfully categorized batch #{batch_number}")
        rescue StandardError => e
          Rails.logger.error("Batch #{batch_number} categorization failed: #{e.message}")
          # Use original transactions for failed batch
          categorized.concat(batch)
        end
      end

      categorized
    end

    def categorize_batch(transactions)
      prompt = build_categorization_prompt_for_batch(transactions)
      response_with_metadata = ai_client.chat(prompt)

      # Handle new response format {text:, usage:}
      response_text = response_with_metadata.is_a?(Hash) ? response_with_metadata[:text] : response_with_metadata
      usage = response_with_metadata.is_a?(Hash) ? response_with_metadata[:usage] : {}

      # Accumulate usage for total cost tracking
      if usage.present?
        @total_categorization_usage[:prompt_token_count] += usage[:prompt_token_count] || 0
        @total_categorization_usage[:candidates_token_count] += usage[:candidates_token_count] || 0
        @total_categorization_usage[:total_token_count] += usage[:total_token_count] || 0
      end

      if response_text.blank?
        Rails.logger.warn("AI returned empty response for categorization")
        return transactions
      end

      # Clean and parse response
      cleaned_response = clean_ai_response(response_text)
      parsed_result = parse_ai_response(cleaned_response, "ai_categorization")

      if parsed_result.success?
        merge_categorization_with_original(transactions, parsed_result.payload["transactions"])
      else
        Rails.logger.error("Failed to parse AI categorization response: #{parsed_result.errors.full_messages}")
        transactions
      end
    end

    def build_categorization_prompt_for_batch(transactions)
      # Build taxonomy with IDs for AI
      taxonomy = build_category_taxonomy_payload(categories)

      <<~PROMPT
        You are categorizing bank transactions. Add category information to each transaction.

        AVAILABLE CATEGORIES (select by ID):
        #{JSON.pretty_generate(taxonomy)}

        TRANSACTIONS TO CATEGORIZE:
        #{JSON.pretty_generate(transactions)}

        For each transaction, add:
        - category_id: Main category ID (integer from the taxonomy above)
        - sub_category_id: Subcategory ID (integer, optional if applicable)
        - merchant: Extracted merchant/business name
        - transaction_type: One of: income, fixed_expense, variable_expense, transfer_out, transfer_in
        - confidence: Overall confidence (0.0 to 1.0)
        - category_confidence: Category assignment confidence (0.0 to 1.0)
        - transaction_type_confidence: Transaction type confidence (0.0 to 1.0)

        IMPORTANT:
        - Return ALL transactions from the input
        - Keep original date, description, amount, reference fields unchanged
        - Use category_id and sub_category_id (numbers) from the taxonomy above
        - NEVER make up category IDs - only use IDs from the provided taxonomy
        - If unsure, use category_id: null and set category_confidence: 0.0
        - Be conservative with confidence scores (use 0.5-0.7 when uncertain)

        Return JSON with this structure:
        {
          "transactions": [
            {
              "date": "...",
              "description": "...",
              "amount": ...,
              "reference": "...",
              "category_id": 123,
              "sub_category_id": 456,
              "merchant": "Merchant name",
              "transaction_type": "variable_expense",
              "confidence": 0.85,
              "category_confidence": 0.90,
              "transaction_type_confidence": 0.80
            }
          ]
        }
      PROMPT
    end

    def build_category_taxonomy_payload(categories)
      # Group categories by parent with IDs
      parents = categories.select { |c| c.parent_id.nil? }
      taxonomy = []

      parents.each do |parent|
        children = categories.select { |c| c.parent_id == parent.id }
        taxonomy << {
          id: parent.id,
          name: parent.name,
          icon: parent.icon,
          subcategories: children.map { |c| { id: c.id, name: c.name, icon: c.icon } }
        }
      end

      taxonomy
    end

    def merge_categorization_with_original(original_transactions, categorized_transactions)
      return original_transactions if categorized_transactions.blank?

      # Create a map by description for quick lookup
      categorized_map = {}
      categorized_transactions.each do |cat_trans|
        key = cat_trans["description"]&.downcase&.strip
        categorized_map[key] = cat_trans if key.present?
      end

      # Merge categorization data with original
      original_transactions.map do |original|
        description_key = original["description"]&.downcase&.strip || original[:description]&.downcase&.strip
        categorized = categorized_map[description_key]

        if categorized
          merge_categorization_fields(original, categorized)
        else
          original
        end
      end
    end

    def merge_categorization_fields(original, categorized)
      merged = original.dup

      # Only apply categorization if confidence meets threshold
      category_confidence = categorized["category_confidence"].to_f

      if category_confidence >= MIN_CATEGORY_CONFIDENCE
        # AI now returns IDs directly - no name resolution needed!
        merged["category_id"] = categorized["category_id"] if categorized["category_id"].present?
        merged["sub_category_id"] = categorized["sub_category_id"] if categorized["sub_category_id"].present?
      else
        Rails.logger.info(
          "Skipping low-confidence categorization (#{category_confidence.round(2)}) for: " \
          "#{original["description"]&.truncate(50)}"
        )
      end

      # Always merge these fields (for analysis and merchant extraction)
      merged["merchant"] = categorized["merchant"] if categorized["merchant"].present?
      merged["transaction_type"] = categorized["transaction_type"] if categorized["transaction_type"].present?
      merged["confidence"] = categorized["confidence"] if categorized["confidence"].present?
      merged["category_confidence"] = categorized["category_confidence"] if categorized["category_confidence"].present?
      if categorized["transaction_type_confidence"].present?
        merged["transaction_type_confidence"] = categorized["transaction_type_confidence"]
      end

      merged
    end

    def clean_ai_response(response)
      cleaned = response.strip

      # Remove markdown formatting
      cleaned = cleaned.gsub(/^```json\s*/m, "")
      cleaned = cleaned.gsub(/^```\s*/m, "")
      cleaned = cleaned.gsub(/\s*```$/m, "")

      cleaned.strip
    end

    def context_for_logging
      {
        statement_file_id: statement_file.id,
        user_id: user.id,
        transaction_count: extract_transactions(@data).size,
        category_count: categories.size
      }
    end

    def log_categorization_cost(usage)
      return unless usage.present? && usage[:total_token_count] > 0

      # Gemini 2.0 Flash Lite pricing
      input_tokens = usage[:prompt_token_count] || 0
      output_tokens = usage[:candidates_token_count] || 0
      total_tokens = usage[:total_token_count] || (input_tokens + output_tokens)

      input_cost_usd = (input_tokens / 1_000_000.0) * Ai::Concerns::Pricing::Gemini::FLASH_LITE_INPUT_COST
      output_cost_usd = (output_tokens / 1_000_000.0) * Ai::Concerns::Pricing::Gemini::FLASH_LITE_OUTPUT_COST
      total_cost_usd = input_cost_usd + output_cost_usd
      total_cost_mxn = total_cost_usd * Ai::Concerns::Pricing::USD_TO_MXN_RATE

      Rails.logger.info(
        "Categorization cost: $#{total_cost_usd.round(4)} USD / $#{total_cost_mxn.round(2)} MXN " \
        "(#{input_tokens} input + #{output_tokens} output = #{total_tokens} total tokens)"
      )

      # Store in usage_metadata with categorization-specific keys
      current_metadata = @statement_file.usage_metadata || {}
      @statement_file.update(
        usage_metadata: current_metadata.merge(
          "categorization" => {
            "prompt_token_count" => input_tokens,
            "candidates_token_count" => output_tokens,
            "total_token_count" => total_tokens,
            "cost_usd" => total_cost_usd.round(6),
            "cost_mxn" => total_cost_mxn.round(2)
          }
        )
      )
    end
  end
end
