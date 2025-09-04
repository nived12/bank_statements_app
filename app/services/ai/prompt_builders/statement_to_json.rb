require "yaml"

module Ai
  module PromptBuilders
    class StatementToJson
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

      def initialize(bank_name:, account_number:, categories:)
        @bank_name = bank_name
        @account_number = account_number
        @categories = categories
      end

      def build(raw_text:)
        taxonomy_json = taxonomy_payload(@categories).to_json
        fewshots_text = fewshots_block

        <<~PROMPT
          #{build_hybrid_prompt(raw_text, @categories)}

          **CATEGORIZATION PATTERNS:**
          - SPEI ENVIADO, RETIRO, PAGO → "Servicios"
          - DEPOSITO, NOMINA, BONO, RECIBIDO → "Ingresos"
          - SPEI RECIBIDO → "Ingresos"
          - PAGO INTERBANCARIO, PAGO CUENTA, PAGO TARJETA → "Servicios"
          - RETIRO SIN TARJETA → "Servicios"
          - DEPOSITO DE TERCERO → "Ingresos"

          **CATEGORIES (use EXACT names):**
          #{taxonomy_json}

          **TEXT TO PROCESS:**
          #{raw_text}
        PROMPT
      end


      private

      def bbva_specific_instructions
        return "" unless @bank_name.to_s.downcase == "bbva"

        # Determine account type based on account number or statement content
        account_type = determine_bbva_account_type(@account_number)

        if account_type == "credit_card"
          <<~BBVA_CREDIT_INSTRUCTIONS
                           **SPECIFIC FOR BBVA CREDIT CARD STATEMENTS (July 2024+ Format):**
               - Look for transaction lines with double dates (e.g., "21-jun-2025 23-jun-2025")
               - Parse each line with date and amount

               **🚨 CRITICAL SIGN LOGIC - READ CAREFULLY 🚨**
               For BBVA Credit Card statements, the signs are INVERTED from what you see:

               **EXPENSES (Charges/Purchases):**
               - When you see "+ $amount" in the statement → This is an EXPENSE
               - Set amount to NEGATIVE (-amount)#{' '}
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

      private

      def determine_bbva_account_type(account_number)
        # This is a simplified logic - you might want to enhance this
        # based on your actual account number patterns or statement content
        if account_number.to_s.include?("credit") || account_number.to_s.include?("tdc")
          "credit_card"
        else
          "savings" # Default to savings for now
        end
      end

      def build_hybrid_prompt(raw_text, categories)
        # Determine if this is categorization enhancement (hybrid) or full parsing (fallback)
        if is_categorization_only?(raw_text)
          build_categorization_prompt
        else
          build_full_parsing_prompt
        end
      end

      def is_categorization_only?(raw_text)
        # Check if the text looks like it's already parsed transactions (just needs categorization)
        # vs raw statement text that needs full parsing
        lines = raw_text.split("\n")
        transaction_lines = lines.count { |line| line.match?(/\d{2}-[a-z]{3}-\d{4}/) || line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/) }

        # If more than 70% of lines look like transactions, this is likely categorization enhancement
        transaction_lines.to_f / lines.length > 0.7
      end

      def build_categorization_prompt
        <<~PROMPT
          **CATEGORIZATION ENHANCEMENT MODE:**
          - You are enhancing existing transaction data with categories
          - Focus ONLY on categorization and transaction type
          - Use the schema below for the response format

          **REQUIRED FIELDS:**
          - category: Choose from the taxonomy below. Use EXACT category names.
          - transaction_type: "income" or "variable_expense" based on keywords.
          - confidence: 0.8+ for clear matches, 0.6-0.7 for uncertain.
        PROMPT
      end

      def build_full_parsing_prompt
        <<~PROMPT
          **FULL PARSING MODE:**
          - You are parsing raw bank statement text into structured data
          - Extract ALL transaction details: dates, amounts, descriptions, categories
          - Use the complete schema below for the response format

          **REQUIRED FIELDS:**
          - date: "YYYY-MM-DD" format
          - amount: decimal string with 2 decimal places
          - description: transaction description
          - transaction_type: "income", "fixed_expense", or "variable_expense"
          - category: Choose from the taxonomy below
          - confidence: 0.8+ for clear matches, 0.6-0.7 for uncertain
        PROMPT
      end

      def taxonomy_payload(categories)
        parents = categories.where(parent_id: nil).includes(:children).order(:name)
        parents.map do |cat|
          { name: cat.name, subcategories: cat.children.order(:name).pluck(:name) }
        end.presence || [ { name: "Sin Categorizar", subcategories: [] } ]
      end

      def fewshots_block
        path = Rails.root.join("config/ai_fewshots/statement_examples.en.yml")
        return "" unless File.exist?(path)
        yaml = YAML.load_file(path)
        arr = yaml["examples"] || []
        arr.map do |ex|
          <<~EX
            Input: #{ex["text"]}
            Expected:
            #{ex["expected"].to_json}
          EX
        end.join("\n")
      rescue
        ""
      end
    end
  end
end
