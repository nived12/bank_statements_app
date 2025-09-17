# app/services/ai/concerns/prompt_builder.rb
require "yaml"

module Ai
  module Concerns
    module PromptBuilder
      SCHEMA_HINT = <<~JSON
        {
          "opening_balance": "string",
          "closing_balance": "string",
          "transactions": [
            {
              "date": "string",
              "description": "string",
              "amount": "string",
              "transaction_type": "string",
              "bank_entry_type": "string",
              "merchant": "string|null",
              "reference": "string|null",
              "category": "string",
              "sub_category": "string|null",
              "raw_text": "string",
              "confidence": "number",
              "category_confidence": "number",
              "transaction_type_confidence": "number"
            }
          ],
          "financial_summaries": [
            {
              "type": "string",
              "description": "string",
              "amount": "string",
              "date": "string|null",
              "details": "string|null",
              "raw_text": "string"
            }
          ]
        }
      JSON

      def build_full_parsing_prompt(raw_text, bank_name, account_number, categories)
        taxonomy_json = taxonomy_payload(categories).to_json
        fewshots_text = fewshots_block

        prompt = <<~PROMPT
          **FULL PARSING MODE:**
          - You are parsing raw bank statement text into structured data
          - Extract ALL transaction details: dates, amounts, descriptions, categories
          - Use the complete schema below for the response format

          **HANDLING FRAGMENTED OCR DATA:**
          - OCR text may have broken table structures where descriptions and amounts are separated
          - Look for transaction patterns like dates (DD-MMM-YYYY), amounts ($X,XXX.XX), and descriptions
          - Match transactions by proximity - if you see a date and description, look nearby for the corresponding amount
          - Common patterns: "AHORRO MIS METAS", "PAGO TRANSFERENCIA SPEI", "ABONO TRANSFERENCIA SPEI", "PAGO DE TARJETA DE CREDITO"
          - Extract as many transactions as possible, even if some data is incomplete

          **REQUIRED FIELDS:**
          - date: "YYYY-MM-DD" format
          - amount: decimal string with 2 decimal places
          - description: transaction description
          - transaction_type: "income", "fixed_expense", or "variable_expense"
          - category: Choose from the taxonomy below
          - confidence: 0.8+ for clear matches, 0.6-0.7 for uncertain

          **RESPONSE FORMAT:**
          Return a JSON object with this exact structure:
          #{SCHEMA_HINT}

          **IMPORTANT:** Return the full JSON object with opening_balance, closing_balance, and transactions array, even if some fields are null or empty.

          #{bank_specific_instructions(bank_name, account_number)}

          **CATEGORIZATION PATTERNS:**
          - SPEI ENVIADO, RETIRO, PAGO → "Servicios"
          - DEPOSITO, NOMINA, BONO, RECIBIDO → "Ingresos"
          - SPEI RECIBIDO → "Ingresos"
          - PAGO INTERBANCARIO, PAGO CUENTA, PAGO TARJETA → "Servicios"
          - RETIRO SIN TARJETA → "Servicios"
          - DEPOSITO DE TERCERO → "Ingresos"

          **CATEGORIES (use EXACT names):**
          #{taxonomy_json}

          **EXAMPLES (learn from these patterns):**
          #{fewshots_text}

          **TEXT TO PROCESS:**
          #{raw_text}
        PROMPT

        success(prompt)
      rescue => e
        errors.add(:base, "Failed to build full parsing prompt: #{e.message}")
        failure
      end

      def build_categorization_prompt(raw_text, categories)
        # Build a simple, cost-effective prompt for categorization only
        taxonomy_json = taxonomy_payload(categories).to_json

        prompt = <<~PROMPT
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
              }
            ]
          }

          **CATEGORIES (use EXACT names):**
          #{taxonomy_json}

          **TRANSACTIONS TO CATEGORIZE (one per line):**
          #{raw_text}

          **CRITICAL INSTRUCTIONS:**
          1. Count the number of lines above
          2. Create exactly that many transactions in the response
          3. Each line = one transaction
          4. Do not skip any lines
          5. Return ALL transactions
          6. Use the EXACT category names from the taxonomy above
          7. For subcategories, use the EXACT subcategory names from the taxonomy
          8. Use null for sub_category if no subcategory applies
        PROMPT

        success(prompt)
      rescue => e
        errors.add(:base, "Failed to build categorization prompt: #{e.message}")
        failure
      end

      private

      def taxonomy_payload(categories)
        unless categories.respond_to?(:where)
          raise ArgumentError, "Categories must be an ActiveRecord relation, got #{categories.class}"
        end

        parents = categories.where(parent_id: nil).includes(:children).order(:name)
        parents.map do |cat|
          { name: cat.name, subcategories: cat.children.order(:name).pluck(:name) }
        end.presence || [ { name: "Sin Categorizar", subcategories: [] } ]
      end

      def bank_specific_instructions(bank_name, account_number)
        case bank_name.to_s.downcase
        when "bbva"
          bbva_specific_instructions(account_number)
        when "santander"
          santander_specific_instructions
        else
          ""
        end
      end

      def bbva_specific_instructions(account_number)
        account_type = determine_bbva_account_type(account_number)

        if account_type == "credit_card"
          <<~BBVA_CREDIT_INSTRUCTIONS
            **SPECIFIC FOR BBVA CREDIT CARD STATEMENTS (July 2024+ Format):**
            - Look for transaction lines with double dates (e.g., "21-jun-2025 23-jun-2025")
            - Parse each line with date and amount

            **🚨 CRITICAL SIGN LOGIC - READ CAREFULLY 🚨**
            For BBVA Credit Card statements, the signs are INVERTED from what you see:

            **EXPENSES (Charges/Purchases):**
            - When you see "+ $amount" in the statement → This is an EXPENSE
            - Set amount to NEGATIVE (-amount)
            - Set transaction_type to "variable_expense"
            - Set bank_entry_type to "debit"

            **PAYMENTS (Credits/Refunds):**
            - When you see "- $amount" in the statement → This is a PAYMENT
            - Set amount to POSITIVE (+amount)
            - Set transaction_type to "income"
            - Set bank_entry_type to "credit"

            **EXAMPLES:**
            - "+ $193.20" → amount: -193.20, type: "variable_expense", entry: "debit"
            - "- $54,538.87" → amount: 54538.87, type: "income", entry: "credit"

            **CATEGORIZATION PRIORITY FOR CREDIT CARDS:**
            - Restaurants/Food: STARBUCKS, TST*THE WINDOW, MCDONALDS, etc. → "Comida" > "Restaurantes"
            - Retail: HOME DEPOT, WALMART, AMAZON, etc. → "Compras" > "Hogar" or "Tecnología"
            - Entertainment: TICKETMASTER, NETFLIX, SPOTIFY, etc. → "Entretenimiento" > appropriate subcategory
            - Gas/Transport: SHELL, PEMEX, UBER, etc. → "Transporte" > "Gasolina" or "Transporte Público"
            - Services: CFE, TELMEX, etc. → "Servicios" > appropriate subcategory
            - Payments/Refunds: Any negative amount → "Ingresos" > "Otros Ingresos"

            - Extract reference numbers and merchant names
            - Handle USD conversion lines (e.g., "USD $10.07 TIPO DE CAMBIO $19.19")
            - Parse EVERY transaction line you see - don't skip any
            - **IMPORTANT**: Always provide a category and subcategory for each transaction
            - **REMEMBER**: + in statement = EXPENSE (negative), - in statement = PAYMENT (positive)
          BBVA_CREDIT_INSTRUCTIONS
        else
          <<~BBVA_SAVINGS_INSTRUCTIONS
            **SPECIFIC FOR BBVA SAVINGS ACCOUNT STATEMENTS:**
            - Look for transaction lines with dates and amounts
            - **CRITICAL SIGN LOGIC FOR SAVINGS:**
              * Credits to savings account = INCOME → Use POSITIVE amounts and "income" type
              * Debits from savings account = EXPENSES → Use NEGATIVE amounts and "variable_expense" type
            - Common transactions: deposits, withdrawals, transfers, fees
            - Extract reference numbers and transaction descriptions
            - Parse EVERY transaction line you see - don't skip any
            - For savings accounts, credits increase balance (positive), debits decrease balance (negative)
          BBVA_SAVINGS_INSTRUCTIONS
        end
      end

      def santander_specific_instructions
        <<~SANTANDER_INSTRUCTIONS
          **SPECIFIC FOR SANTANDER STATEMENTS:**
          - Look for transaction patterns with dates (DD-MMM-YYYY format)
          - Common patterns: "AHORRO MIS METAS", "PAGO TRANSFERENCIA SPEI", "ABONO TRANSFERENCIA SPEI"
          - Handle fragmented OCR data where descriptions and amounts may be separated
          - Match transactions by proximity - if you see a date and description, look nearby for the amount
          - Extract as many transactions as possible, even if some data is incomplete
          - Parse EVERY transaction line you see - don't skip any
        SANTANDER_INSTRUCTIONS
      end

      def determine_bbva_account_type(account_number)
        # This is a simplified logic - you might want to enhance this
        # based on your actual account number patterns or statement content
        return "credit_card" if account_number.to_s.length >= 16
        "savings"
      end

      def fewshots_block
        examples = load_fewshot_examples
        return "" if examples.empty?

        examples.map do |ex|
          <<~EXAMPLE
            **Input:** #{ex["text"]}
            **Expected Output:**
            ```json
            #{ex["expected"].to_json}
            ```
          EXAMPLE
        end.join("\n")
      end

      def load_fewshot_examples
        file_path = Rails.root.join("config", "ai_fewshots", "statement_examples.en.yml")
        return [] unless File.exist?(file_path)

        yaml_content = YAML.load_file(file_path)
        yaml_content["examples"] || []
      rescue => e
        Rails.logger.error("Failed to load fewshot examples: #{e.message}")
        []
      end
    end
  end
end
