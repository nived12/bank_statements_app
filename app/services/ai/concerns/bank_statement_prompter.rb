# app/services/ai/concerns/bank_statement_prompter.rb
module Ai
  module Concerns
    module BankStatementPrompter
      def build_bank_statement_prompt(text, bank_name, account_type)
        begin
          base_prompt = build_base_prompt(text, bank_name, account_type)

          bank_specific_section = case bank_name.to_s.upcase
          when "BANORTE", "BANCO BANORTE"
            case account_type.to_s.downcase
            when "debit", "savings"
              get_banorte_debit_instructions
            end
          when "BBVA", "BBVA BANCOMER", "BANCO BBVA BANCOMER"
            case account_type.to_s.downcase
            when "credit"
              get_bbva_credit_instructions
            when "debit", "savings"
              get_bbva_debit_instructions
            end
          when "SANTANDER", "BANCO SANTANDER"
            case account_type.to_s.downcase
            when "credit"
              get_santander_credit_instructions
            when "debit", "savings"
              get_santander_debit_instructions
            end
          end

          prompt = base_prompt.gsub("**BANK-SPECIFIC INSTRUCTIONS:**", bank_specific_section.to_s)
          success(prompt)
        rescue => e
          errors.add(:base, "Failed to build bank statement prompt: #{e.message}")
          failure
        end
      end

      def build_transaction_enhancement_prompt(transactions, bank_name, account_type)
        begin
          # Use all transactions - batch processing is handled at the service level
          limited_transactions = transactions

          prompt = <<~PROMPT
            **TRANSACTION ENHANCEMENT:**
            You are an expert at categorizing bank transactions. Enhance the provided transactions with categorization and merchant information.

            **BANK:** #{bank_name}
            **ACCOUNT TYPE:** #{account_type.upcase}

            **INSTRUCTIONS:**
            - You will receive a list of transactions that have already been extracted from a bank statement
            - Process ALL transactions provided - this may be a batch of transactions from a larger statement
            - For each transaction, add the following fields:
              - `category`: Assign the most appropriate category from the provided list
              - `sub_category`: Assign a sub-category if applicable
              - `merchant`: Extract the merchant name from the description
              - `transaction_type`: Determine if it's "income", "fixed_expense", or "variable_expense" based on the description
              - `confidence`: Overall confidence score (0.0-1.0) for the categorization
              - `category_confidence`: Confidence score (0.0-1.0) specifically for the category assignment
              - `transaction_type_confidence`: Confidence score (0.0-1.0) specifically for the transaction type

            **TRANSACTION TYPE GUIDELINES:**
            - `income`: Salary, bonuses, refunds, interest earned, transfers received
            - `fixed_expense`: Rent, mortgage, insurance, subscriptions, utilities, loan payments, recurring services
            - `variable_expense`: Groceries, dining out, entertainment, shopping, gas, one-time purchases

            **REQUIRED JSON FORMAT (NO MARKDOWN):**
            #{Concerns::PromptBuilder::SCHEMA_HINT}

            **CRITICAL: Return ONLY the JSON object above, no markdown, no ```json, no explanations.**
            **NOTE: For transaction enhancement, you only need to populate the transactions array. Set opening_balance, closing_balance, and financial_summaries to null.**

            **CATEGORIES:**
            #{taxonomy_payload(categories).to_json}

            **TRANSACTIONS TO ENHANCE:**
            #{limited_transactions.to_json}
          PROMPT

          # Validate that the prompt is not too large or contains invalid characters
          if prompt.length > 100000
            errors.add(:base, "Prompt too large: #{prompt.length} characters")
            return failure
          end

          # Validate that the transactions JSON is valid
          begin
            JSON.parse(transactions.to_json)
          rescue JSON::ParserError => e
            errors.add(:base, "Invalid transactions JSON: #{e.message}")
            return failure
          end

          success(prompt)
        rescue => e
          errors.add(:base, "Failed to build transaction enhancement prompt: #{e.message}")
          failure
        end
      end

      private

      # Bank-specific instruction methods
      def get_banorte_debit_instructions
        <<~BANORTE_SPECIFIC
          **BANORTE DEBIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - 'DETALLE' and 'NÓMINA BANORTE S/CH'
          - 'Resumen del periodo'
          - Ends with 'Saldo Global'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table with these headers:
          - 'FECHA' (Date) - Extract the exact date format like "10-JUN-25", "11-JUN-25"
          - 'DESCRIPCIÓN / ESTABLECIMIENTO' (Description/Merchant) - Extract the FULL description text
          - 'MONTO DEL DEPOSITO' (Income amount - positive)
          - 'MONTO DEL RETIRO' (Expense amount - negative)
          - 'SALDO' (Balance - ignore this column)
          - Section ends with 'OTROS▼'

          **CRITICAL EXTRACTION RULES:**
          - Extract the EXACT date from the FECHA column (e.g., "10-JUN-25", "11-JUN-25")
          - Extract the COMPLETE description from DESCRIPCIÓN / ESTABLECIMIENTO column
          - **IMPORTANT: Extract MEANINGFUL merchant/establishment names, not internal bank codes**
          - **AVOID: SPEIBCO codes, beneficiary numbers, internal references**
          - **EXTRACT: Actual merchant names like "Walmart", "Starbucks", "Gas Station", "Restaurant Name"**
          - If the description contains only internal codes (like SPEIBCO:012BENEF:), try to find the actual merchant name elsewhere in the transaction
          - For deposits: use MONTO DEL DEPOSITO value as positive amount
          - For withdrawals: use MONTO DEL RETIRO value as negative amount
          - If you cannot find a meaningful description, use the raw text from the description column as-is
          - ALWAYS return ALL transactions - never skip any transaction

        BANORTE_SPECIFIC
      end

      def get_bbva_credit_instructions
        <<~BBVA_CREDIT_SPECIFIC
          **BBVA CREDIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - 'RESUMEN DE CARGOS Y ABONOS DEL PERIODO'
          - Ends with 'Pagos y abonos' and then 'PAGO PARA NO GENERAR INTERESES'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with 'CARGOS,COMPRAS Y ABONOS REGULARES(NO A MESES)' with these headers:
          - 'Fecha de la operación' (Operation Date)
          - 'Fecha de cargo' (Charge Date)
          - 'Descripción del movimiento' (Description)
          - 'MONTO' (Amount - (+) is expense, (-) is income)

        BBVA_CREDIT_SPECIFIC
      end

      def get_bbva_debit_instructions
        <<~BBVA_DEBIT_SPECIFIC
          **BBVA DEBIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - 'Información Financiera'
          - Section with header 'Comportamiento' containing:
            - 'Saldo Anterior' (Previous Balance)
            - 'Depósitos / Abonos' (Deposits/Credits)
            - 'Retiros / Cargos' (Withdrawals/Charges)
            - 'Saldo Final' (Final Balance)
            - 'Saldo Promedio Mínimo Mensual' (Average Minimum Monthly Balance)

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with 'Detalle de Movimientos Realizados' with these headers:
          - 'FECHA' (Date)
            - 'OPER' (Operation Date)
            - 'LIQ' (Liquidation Date)
          - 'DESCRIPCIÓN' (Description)
          - 'REFERENCIA' (Reference)
          - 'CARGOS' (Charges - this is expense (-))
          - 'ABONOS' (Credits - this is income (+))
          - 'SALDO' (Balance)
            - 'OPERACIÓN' (Operation Balance)
            - 'LIQUIDACIÓN' (Liquidation Balance)
          - Section ends with 'Total de Movimientos'

        BBVA_DEBIT_SPECIFIC
      end

      def get_santander_credit_instructions
        <<~SANTANDER_CREDIT_SPECIFIC
          **SANTANDER CREDIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - 'RESUMEN DE CARGOS Y ABONOS DEL PERIODO'
          - Ends with 'Pagos y abonos' and then 'PAGO PARA NO GENERAR INTERESES'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with 'DESGLOSE DE MOVIMIENTOS' with these headers:
          - 'Fecha de la operación' (Operation Date)
          - 'Fecha de cargo' (Charge Date)
          - 'Descripción del movimiento' (Description)
          - 'Monto' (Amount - (+) is expense, (-) is income)
          - The PDF has 9-10 pages total, but the main transactions are on pages 4-5

        SANTANDER_CREDIT_SPECIFIC
      end

      def get_santander_debit_instructions
        <<~SANTANDER_DEBIT_SPECIFIC
          **SANTANDER DEBIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - 'Resumen del periodo'
          - Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table with these headers:
          - 'FECHA' (Date)
          - 'DESCRIPCIÓN' (Description)
          - 'MONTO' (Amount - (+) is income, (-) is expense)
          - 'SALDO' (Balance - ignore this column)

        SANTANDER_DEBIT_SPECIFIC
      end

      def get_sign_logic_for_account_type(account_type)
        case account_type.to_s.downcase
        when "credit"
          <<~SIGN_LOGIC
            **CREDIT CARD SIGN LOGIC:**
            - Transactions with (-) are INCOME (payments, credits) - store as POSITIVE
            - Transactions with (+) are EXPENSES (purchases, charges) - store as NEGATIVE
            - This is because credit card statements show your debt, so payments reduce debt (positive) and purchases increase debt (negative)
          SIGN_LOGIC
        when "debit", "savings", "checking"
          <<~SIGN_LOGIC
            **DEBIT/SAVINGS SIGN LOGIC:**
            - Transactions with (+) are INCOME (deposits, credits) - store as POSITIVE
            - Transactions with (-) are EXPENSES (withdrawals, charges) - store as NEGATIVE
            - This is because debit/savings accounts show your money, so deposits increase money (positive) and withdrawals decrease money (negative)
          SIGN_LOGIC
        else
          <<~SIGN_LOGIC
            **GENERIC SIGN LOGIC:**
            - Positive amounts are INCOME - store as POSITIVE
            - Negative amounts are EXPENSES - store as NEGATIVE
          SIGN_LOGIC
        end
      end

      def get_bank_specific_instructions(bank_name, account_type)
        case bank_name.to_s.upcase
        when "BANORTE", "BANCO BANORTE"
          case account_type.to_s.downcase
          when "debit", "savings"
            <<~BANORTE_INSTRUCTIONS
              **BANORTE DEBIT CARD SPECIFIC INSTRUCTIONS:**
              - Look for transaction table with headers: FECHA, DESCRIPCIÓN / ESTABLECIMIENTO, MONTO DEL DEPOSITO, MONTO DEL RETIRO
              - MONTO DEL DEPOSITO = Income (positive)
              - MONTO DEL RETIRO = Expense (negative)
              - Extract complete descriptions from DESCRIPCIÓN / ESTABLECIMIENTO column
            BANORTE_INSTRUCTIONS
          else
            ""
          end
        when "BBVA", "BBVA BANCOMER", "BANCO BBVA BANCOMER"
          case account_type.to_s.downcase
          when "credit"
            <<~BBVA_CREDIT_INSTRUCTIONS
              **BBVA CREDIT CARD SPECIFIC INSTRUCTIONS:**
              - Look for transaction table with headers: Fecha de la operación, Descripción del movimiento, MONTO
              - MONTO with (+) = Expense (negative)
              - MONTO with (-) = Income (positive)
              - Extract complete descriptions from Descripción del movimiento column
            BBVA_CREDIT_INSTRUCTIONS
          when "debit", "savings"
            <<~BBVA_DEBIT_INSTRUCTIONS
              **BBVA DEBIT CARD SPECIFIC INSTRUCTIONS:**
              - Look for transaction table with headers: FECHA, DESCRIPCIÓN, CARGOS, ABONOS
              - CARGOS = Expense (negative)
              - ABONOS = Income (positive)
              - Extract complete descriptions from DESCRIPCIÓN column
            BBVA_DEBIT_INSTRUCTIONS
          else
            ""
          end
        when "SANTANDER", "BANCO SANTANDER"
          case account_type.to_s.downcase
          when "credit"
            <<~SANTANDER_CREDIT_INSTRUCTIONS
              **SANTANDER CREDIT CARD SPECIFIC INSTRUCTIONS:**
              - Look for transaction table with headers: Fecha, Descripción, Importe
              - Importe with (+) = Expense (negative)
              - Importe with (-) = Income (positive)
              - Extract complete descriptions from Descripción column
            SANTANDER_CREDIT_INSTRUCTIONS
          when "debit", "savings"
            <<~SANTANDER_DEBIT_INSTRUCTIONS
              **SANTANDER DEBIT CARD SPECIFIC INSTRUCTIONS:**
              - Look for transaction table with headers: Fecha, Concepto, Cargo, Abono
              - Cargo = Expense (negative)
              - Abono = Income (positive)
              - Extract complete descriptions from Concepto column
            SANTANDER_DEBIT_INSTRUCTIONS
          else
            ""
          end
        else
          ""
        end
      end

      def build_base_prompt(text, bank_name, account_type)
        sign_logic = get_sign_logic_for_account_type(account_type)
        bank_instructions = get_bank_specific_instructions(bank_name, account_type)

        <<~PROMPT
          **BANK STATEMENT TEXT PROCESSING:**
          You are an expert at reading bank statements. Analyze this text and extract ALL transactions and financial summary.

          **BANK:** #{bank_name}
          **ACCOUNT TYPE:** #{account_type.upcase}

          **INSTRUCTIONS:**
          - This text has been extracted from a bank statement PDF
          - Look for the transaction table and the financial summary table
          - Extract EVERY single transaction row from the transaction table
          - Extract the financial summary from the financial summary table
          - Look for common transaction table headers like: FECHA, DESCRIPCIÓN, MONTO, etc.
          - Pay attention to the sign conventions used by this bank
          - **CRITICAL: Every transaction MUST have a non-empty description field**
          - **CRITICAL: Extract the EXACT date format from the statement (e.g., "10-JUN-25")**
          - **CRITICAL: Extract the COMPLETE description text, not just partial text**
          - **CRITICAL: ALL transactions in bank statements have descriptions - extract them completely**
          - Return ONLY valid JSON, no markdown, no code blocks, no ```json wrapper
          - Start your response directly with { and end with }

          **BANK-SPECIFIC INSTRUCTIONS:**

          **SIGN LOGIC FOR #{account_type.upcase}:**
          #{sign_logic}

          #{bank_instructions}

          **REQUIRED JSON FORMAT (NO MARKDOWN):**
          #{Concerns::PromptBuilder::SCHEMA_HINT}

          **CRITICAL: Return ONLY the JSON object above, no markdown, no ```json, no explanations.**

          **CATEGORIES:**
          #{taxonomy_payload(categories).to_json}

          **BANK STATEMENT TEXT:**
          #{text}
        PROMPT
      end
    end
  end
end
