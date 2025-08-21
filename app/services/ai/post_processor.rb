# app/services/ai/post_processor.rb
require "json"

module Ai
  class PostProcessor
    def initialize(client: Ai::Client.new)
      @client = client
    end

        def call(raw_text:, bank_name:, account_number:, categories:)
      # Intelligent AI processing - handles both scenarios:
      # 1. Raw text (AI fallback) - full parsing
      # 2. Parsed transactions (hybrid) - categorization enhancement

      if is_parsed_transactions?(raw_text)
        # Hybrid mode: enhance existing transactions with categories
        process_hybrid_enhancement(raw_text, categories)
      else
        # Fallback mode: parse raw text into transactions
        process_fallback_parsing(raw_text, bank_name, account_number, categories)
      end
    rescue => e
      Rails.logger.error("Ai::PostProcessor error: #{e.message}")
      Rails.logger.error("AI: Raw text length: #{raw_text.length}")
      Rails.logger.error("AI: Categories count: #{categories.count}")
      nil
    end

    private

    def normalize!(json)
      json["transactions"] ||= []

      json["transactions"].each do |t|
        # Ensure required fields are present
        t["category"] ||= "Sin Categorizar"
        t["transaction_type"] ||= "variable_expense"

        # Normalize confidence
        t["confidence"] = t["confidence"].to_f.clamp(0.0, 1.0) if t.key?("confidence")
      end
    end

    def validate_spanish_banking_terms!(json)
      # Look for Spanish banking terms in raw_text to detect potential misinterpretations
      json["transactions"].each do |t|
        raw_text = t["raw_text"]&.downcase || ""

        # If raw text contains Spanish banking terms, validate the interpretation
        if raw_text.include?("importe cargos") || raw_text.include?("cargos")
          # CARGOS should be negative (expenses)
          if t["amount"].to_f > 0
            Rails.logger.warn("Spanish banking term validation: CARGOS amount should be negative, correcting #{t['amount']} to #{-t['amount'].abs}")
            t["amount"] = -t["amount"].abs
            t["transaction_type"] = "variable_expense"
            t["bank_entry_type"] = "debit"
          end
        elsif raw_text.include?("importe abonos") || raw_text.include?("abonos")
          # ABONOS should be positive (income)
          if t["amount"].to_f < 0
            Rails.logger.warn("Spanish banking term validation: ABONOS amount should be positive, correcting #{t['amount']} to #{t['amount'].abs}")
            t["amount"] = t["amount"].abs
            t["transaction_type"] = "income"
            t["bank_entry_type"] = "credit"
          end
        end
      end
    end

    def validate_bbva_credit_card!(json)
      # Additional validation specific to BBVA credit card statements
      json["transactions"].each do |t|
        raw_text = t["raw_text"]&.downcase || ""

        # Check for BBVA credit card specific patterns
        if raw_text.include?("anualidad") || raw_text.include?("fee")
          # Annual fees should be negative expenses
          if t["amount"].to_f > 0
            Rails.logger.warn("BBVA credit card validation: Annual fee should be negative, correcting #{t['amount']} to #{-t['amount'].abs}")
            t["amount"] = -t["amount"].abs
            t["transaction_type"] = "variable_expense"
            t["bank_entry_type"] = "debit"
          end
        elsif raw_text.include?("pago tdc") || raw_text.include?("payment")
          # Credit card payments should be positive income
          if t["amount"].to_f < 0
            Rails.logger.warn("BBVA credit card validation: Payment should be positive, correcting #{t['amount']} to #{t['amount'].abs}")
            t["amount"] = t["amount"].abs
            t["transaction_type"] = "income"
            t["bank_entry_type"] = "credit"
          end
        end

        # Validate transaction types based on amount and context
        validate_transaction_type!(t)
      end
    end

    def validate_transaction_types!(json)
      # Final validation to ensure all transaction types are consistent with amounts
      json["transactions"].each do |t|
        amount = t["amount"].to_f
        current_type = t["transaction_type"]
        current_bank_type = t["bank_entry_type"]

        # Ensure transaction type matches amount sign
        if amount < 0 && current_type != "variable_expense"
          Rails.logger.warn("Transaction type validation: Negative amount should be variable_expense, correcting #{current_type}")
          t["transaction_type"] = "variable_expense"
          t["bank_entry_type"] = "debit"
        elsif amount > 0 && current_type != "income"
          Rails.logger.warn("Transaction type validation: Positive amount should be income, correcting #{current_type}")
          t["transaction_type"] = "income"
          t["bank_entry_type"] = "credit"
        end

        # Ensure bank entry type is consistent
        if amount < 0 && current_bank_type != "debit"
          t["bank_entry_type"] = "debit"
        elsif amount > 0 && current_bank_type != "credit"
          t["bank_entry_type"] = "credit"
        end
      end
    end

    def validate_transaction_type!(transaction)
      amount = transaction["amount"].to_f
      current_type = transaction["transaction_type"]

      # Ensure transaction type matches amount sign
      if amount < 0 && current_type != "variable_expense"
        Rails.logger.warn("Transaction type validation: Negative amount should be variable_expense, correcting #{current_type}")
        transaction["transaction_type"] = "variable_expense"
        transaction["bank_entry_type"] = "debit"
      elsif amount > 0 && current_type != "income"
        Rails.logger.warn("Transaction type validation: Positive amount should be income, correcting #{current_type}")
        transaction["transaction_type"] = "income"
        transaction["bank_entry_type"] = "credit"
      end
    end

    def normalize_balance(balance)
      return nil if balance.nil?

      case balance
      when String
        # Remove commas and convert to float
        balance.to_s.tr(",", "").to_f
      when Numeric
        balance.to_f
      else
        balance.to_f
      end
    end

    def shorten_transaction_descriptions(text)
      # Split into lines and shorten each transaction description
      lines = text.split("\n")
      shortened_lines = lines.map do |line|
        line = line.strip
        next line if line.empty?

        # Extract key words for categorization
        words = line.split(/\s+/)
        key_words = words.select do |word|
          # Keep important words for categorization
          word.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)$/i) ||
          word.match?(/^(BITSO|OXXO|HSBC|BBVA|APPTEGY|INFONAVIT|APIC|MBAN|PORTABILIDAD)$/i) ||
          word.length <= 8  # Keep short words
        end

        # Limit to first 10 key words to avoid token limits
        key_words.first(10).join(" ")
      end

      shortened_lines.join("\n")
    end

        def is_parsed_transactions?(raw_text)
      # Check if the input looks like already parsed transactions
      # vs raw statement text that needs parsing
      lines = raw_text.split("\n")

      # Look for transaction-like patterns in descriptions
      transaction_lines = lines.count do |line|
        line = line.strip
        next false if line.empty?

        # Check for common transaction keywords
        line.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)/i) ||
        # Check for reference numbers and codes
        line.match?(/\b\d{6,}\b/) ||
        # Check for company names
        line.match?(/\b(BITSO|OXXO|HSBC|BBVA|APPTEGY|INFONAVIT|APIC|MBAN|PORTABILIDAD)\b/i)
      end

      # If more than 60% of lines look like transaction descriptions, this is likely parsed data
      transaction_lines.to_f / lines.length > 0.6
    end

    def process_hybrid_enhancement(parsed_text, categories)
      # Hybrid mode: enhance existing transactions with categories
      # Extract only essential keywords for categorization
      essential_text = extract_keywords_inline(parsed_text)

      prompt = build_categorization_prompt(essential_text, categories)
      content = @client.chat(prompt)

      parse_ai_response(content, "ai_enhanced_parser")
    end

    def extract_keywords_inline(text)
      # INLINE METHOD: Process text directly without calling external method
      lines = text.split("\n")
      result_lines = []

      lines.each do |line|
        line = line.strip
        next if line.empty?

        words = line.split(/\s+/)
        # Take first 3-4 words for categorization
        result_lines << words.first(4).join(" ")
      end

      result_lines.join("\n")
    end

    def process_fallback_parsing(raw_text, bank_name, account_number, categories)
      # Fallback mode: parse raw text into transactions
      prompt = Ai::PromptBuilders::StatementToJson
        .new(bank_name: bank_name, account_number: account_number, categories: categories)
        .build(raw_text: raw_text)

      content = @client.chat(prompt)

      parse_ai_response(content, "ai_parser_fallback")
    end

    def build_categorization_prompt(raw_text, categories)
      # Build a simple, cost-effective prompt for categorization only
      taxonomy = build_category_taxonomy(categories)

      <<~PROMPT
        You are a transaction categorizer. Process the following transaction descriptions and return them in JSON format.

        **INPUT FORMAT: Each line below represents a separate transaction.**

        **RULES:**
        - SPEI ENVIADO, RETIRO, PAGO → "Servicios" + "variable_expense"
        - DEPOSITO, NOMINA, BONO, RECIBIDO → "Ingresos" + "income"
        - SPEI RECIBIDO → "Ingresos" + "income"
        - PAGO INTERBANCARIO, PAGO CUENTA, PAGO TARJETA → "Servicios" + "variable_expense"
        - RETIRO SIN TARJETA → "Servicios" + "variable_expense"
        - DEPOSITO DE TERCERO → "Ingresos" + "income"
        - NETFLIX, SPOTIFY, CFE, TELMEX, GAS → "Servicios" + "fixed_expense"

        **REQUIRED FORMAT:**
        {
          "transactions": [
            {
              "description": "transaction description",
              "category": "category name",
              "sub_category": "subcategory name or null",
              "merchant": "merchant name or null",
              "transaction_type": "income", "variable_expense", or "fixed_expense",
              "confidence": 0.8,
              "category_confidence": 0.8
            },
            {
              "description": "second transaction description",
              "category": "category name",
              "sub_category": "subcategory name or null",
              "merchant": "merchant name or null",
              "transaction_type": "income", "variable_expense", or "fixed_expense",
              "confidence": 0.8,
              "category_confidence": 0.8
            }
          ]
        }

        **CATEGORIES (Name → ID mapping):**
        #{taxonomy}

        **TRANSACTIONS TO CATEGORIZE (one per line):**
        #{raw_text}

        **CRITICAL INSTRUCTIONS:**
        1. Count the number of lines above
        2. Create exactly that many transactions in the response
        3. Each line = one transaction
        4. Do not skip any lines
        5. Return ALL transactions
        6. Use the category names from the mapping above (e.g., "Ingresos", "Servicios")
        7. For subcategories, use the format "Category > Subcategory" from the mapping
      PROMPT
    end

    def build_category_taxonomy(categories)
      # Build a category name to ID mapping for the prompt
      # This allows AI to return category names, which we then convert to IDs efficiently
      category_mapping = {}

      categories.each do |category|
        category_mapping[category.name] = category.id

        # Include subcategories if they exist
        category.children.each do |subcategory|
          category_mapping["#{category.name} > #{subcategory.name}"] = subcategory.id
        end
      end

      # Return as JSON for the AI to use
      category_mapping.to_json
    end

    def parse_ai_response(content, extraction_source)
      # Parse the AI response and return structured data
      begin
        json = JSON.parse(content)
        {
          "transactions" => json["transactions"] || [],
          "extraction_source" => extraction_source
        }
      rescue JSON::ParserError => e
        Rails.logger.warn("AI returned invalid JSON: #{e.message}")
        nil
      end
    end

    def extract_essential_transaction_keywords(text)
      # Extract only essential keywords for categorization - cost effective approach
      lines = text.split("\n")
      essential_lines = []

      lines.each do |line|
        line = line.strip
        next if line.empty?

        # Extract only the most important words for categorization
        words = line.split(/\s+/)
        essential_words = words.select do |word|
          # Keep only the most important categorization keywords
          word.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)$/i) ||
          word.match?(/^(BITSO|OXXO|HSBC|BBVA|APPTEGY|INFONAVIT|APIC|MBAN|PORTABILIDAD)$/i)
        end

        # Always add a line, even if no keywords found (use first few words)
        if essential_words.any?
          essential_lines << essential_words.first(5).join(" ")
        else
          essential_lines << words.first(3).join(" ")
        end
      end

      # Keep lines separate for better AI processing
      essential_lines.join("\n")
    end

    def extract_keywords_simple(text)
      # SIMPLE METHOD: Just split and take first few words per line
      lines = text.split("\n")
      result_lines = []

      lines.each do |line|
        line = line.strip
        next if line.empty?

        words = line.split(/\s+/)
        # Take first 3-4 words for categorization
        result_lines << words.first(4).join(" ")
      end

      result_lines.join("\n")
    end

    def chunk_by_transaction_count(text)
      # Smart chunking based on transaction count - optimize for AI processing
      lines = text.split("\n")
      chunks = []
      current_chunk = []
      transaction_count = 0

      lines.each do |line|
        line = line.strip
        next if line.empty?

        # Check if this line looks like a transaction
        if is_transaction_line?(line)
          transaction_count += 1
        end

        current_chunk << line

        # Create a new chunk every 8-10 transactions to balance cost vs accuracy
        if transaction_count >= 8
          chunks << current_chunk.join("\n")
          current_chunk = []
          transaction_count = 0
        end
      end

      # Add the last chunk if it has content
      chunks << current_chunk.join("\n") if current_chunk.any?

      chunks
    end

    def is_transaction_line?(line)
      # Simple heuristic to identify transaction lines
      line.match?(/\d{2}-[a-z]{3}-\d{4}/) || # Date pattern
      line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/) || # Amount pattern
      line.match?(/^(SPEI|RETIRO|DEPOSITO|PAGO|NOMINA|BONO|TARJETA|QR|API|INTERBANCARIO|CUENTA|PRESTAMO|ENVIADO|RECIBIDO|TERCERO|NOM|BON|TDC|TERC)/i)
    end
  end
end
