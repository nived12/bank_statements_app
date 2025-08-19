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
          Convert the following bank statement text to STRICT JSON (no markdown).

          You must:
          - Dates: "YYYY-MM-DD".
          - Amount: decimal string (e.g., "1234.56", "-567.89"), NOT scientific notation or floats.
            Use exactly 2 decimal places for cents.
          - transaction_type: one of "income", "fixed_expense", "variable_expense".
            If unsure and amount < 0, default to "variable_expense".
          - bank_entry_type: "credit" or "debit" if determinable; else null.
          - merchant: Extract the business name, store name, or service provider from the transaction.
            If no clear merchant, extract the main transaction description.
          - reference: Extract transaction reference numbers, IDs, codes, or any alphanumeric identifiers.
            Look for patterns like "REF:", "ID:", "TXN:", or standalone codes.
          - IMPORTANT: Treat each transaction as separate even if they have the same concept/merchant.
            If you see multiple lines with the same concept but different amounts or reference numbers,
            create separate transaction entries for each one. Each unique combination of date, amount,
            and reference should be a separate transaction.

          **FINANCIAL SUMMARIES:**
          - Extract financial summary information including:
            * Opening and closing balances
            * Total charges and credits
            * Fees, interest, and commissions
            * Installment payment summaries
            * Any other financial totals or summaries
          - For financial_summaries array:
            * type: "balance", "fee", "interest", "commission", "installment", "total", or "other"
            * description: Clear description of what the summary represents
            * amount: The monetary amount
            * date: Date if available, null if not
            * details: Additional context or breakdown if available
            * raw_text: The original text line

          **CRITICAL FOR SPANISH BANKING STATEMENTS:**
          - If you see columns labeled "IMPORTE CARGOS" and "IMPORTE ABONOS":
            * "IMPORTE CARGOS" = Charges/Expenses → These should be NEGATIVE amounts and "variable_expense" type
            * "IMPORTE ABONOS" = Credits to the account → These should be POSITIVE amounts and "income" type
          - Look for these Spanish terms in the statement headers or column labels
          - When parsing tables with these columns, ensure the amounts align with the correct column meaning

          #{bbva_specific_instructions}

          **TRANSACTION DETECTION RULES:**
          - Look for lines containing dates in DD/MM/YY format
          - Look for lines containing amounts (numbers with commas and 2 decimal places)
          - Skip lines that are clearly headers, totals, or summaries
          - Include lines that have both date and amount, even if they seem similar
          - Each unique transaction should be a separate entry in the transactions array

          - Choose category and optional sub_category ONLY from the taxonomy below.
            IMPORTANT: Use EXACT category names as shown in the taxonomy.
            Look for keywords in the transaction description to match categories:
            * Food/restaurant words → "Comida" category
            * Transport/gas/uber → "Transporte" category
            * Entertainment/movies/games → "Entretenimiento" category
            * Shopping/clothes/tech → "Compras" category
            * Health/medical → "Salud" category
            * Education/courses → "Educación" category
            * Utilities/services → "Servicios" category
            * Income/salary → "Ingresos" category
            If nothing fits, set category="Sin Categorizar" and sub_category=null.
          - Include "raw_text".
          - Include confidences 0..1: "confidence", "category_confidence", "transaction_type_confidence".
          - English keys and values only.
          - Return ONLY JSON shaped like:
          #{SCHEMA_HINT}

          Category taxonomy (choose only from here, use EXACT names):
          #{taxonomy_json}

          Few-shot guidance (examples, NOT the data to parse):
          #{fewshots_text}

          Context:
          - bank_name: #{@bank_name}
          - account_number: #{@account_number}

          Text to convert:
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
