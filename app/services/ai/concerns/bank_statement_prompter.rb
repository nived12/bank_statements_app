# app/services/ai/concerns/bank_statement_prompter.rb
module Ai
  module Concerns
    module BankStatementPrompter
      def build_bank_statement_prompt(text, bank_name, account_type)
        begin
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
          when "HSBC", "HSBC MÉXICO", "BANCO HSBC"
            case account_type.to_s.downcase
            when "credit"
              get_hsbc_credit_instructions
            when "debit", "savings"
              get_hsbc_debit_instructions
            end
          when "NU", "NU BANK", "BANCO NU"
            case account_type.to_s.downcase
            when "debit", "savings"
              get_nu_debit_instructions
            end
          when "RAPPICARD", "RAPPI CARD", "RAPPI CARD CREDIT", "RAPPI"
            case account_type.to_s.downcase
            when "credit"
              get_rappicard_credit_instructions
            end
          when "SCOTIABANK", "SCOTIABANK MÉXICO", "BANCO SCOTIABANK"
            case account_type.to_s.downcase
            when "credit"
              get_scotiabank_credit_instructions
            end
          end

          base_prompt = build_base_prompt(text, bank_name, account_type, bank_specific_section.to_s)
          success(base_prompt)
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
          - 'Monto' (Amount (+) is expense, (-) is income)

        SANTANDER_CREDIT_SPECIFIC
      end

      def get_santander_debit_instructions
        <<~SANTANDER_DEBIT_SPECIFIC
          **SANTANDER DEBIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - Starts with 'Saldo Promedio'
          - Ends with 'Saldo Final'
          - Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with text 'SALDO FINAL DEL PERIODO ANTERIOR' with these headers:
          - 'FECHA' (Date)
          - 'FOLIO' (Reference)
          - 'DESCRIPCION' (Description)
          - 'DEPOSITO' (Deposit - this is income (+))
          - 'RETIRO' (Withdrawal - this is expense (-))
          - 'SALDO' (Balance - ignore this column)

        SANTANDER_DEBIT_SPECIFIC
      end

      def get_hsbc_credit_instructions
        <<~HSBC_CREDIT_SPECIFIC
          **HSBC CREDIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - 'RESUMEN DE CARGOS Y ABONOS DEL PERIODO'
          - Ends with 'PAGO PARA NO GENERAR INTERESES'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with 'DESGLOSE DE MOVIMIENTOS' with these headers:
          - 'i. Fecha de la operación' (Operation Date)
          - 'ii. Fecha de cargo' (Charge Date)
          - 'iii. Descripción del movimiento' (Description)
          - 'iv. Monto' (Amount - (+) is expense, (-) is income)
          - Section ends with 'Total cargos'

        HSBC_CREDIT_SPECIFIC
      end

      def get_hsbc_debit_instructions
        <<~HSBC_DEBIT_SPECIFIC
          **HSBC DEBIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - 'RESUMEN DE CUENTAS'
          - Ends with 'La fecha de corte coincide con el periodo indicado'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with 'DETALLE DE MOVIMIENTOS' with these headers:
          - 'Día' (Day/Date)
          - 'Descripción' (Description)
          - 'Referencia/Serial' (Reference/Serial)
          - 'Retiro/Cargo' (Withdrawal/Charge - this is expense (-))
          - 'Depósito/Abono' (Deposit/Credit - this is income (+))
          - 'Saldo' (Balance - ignore this column)
          - Section ends with 'CoDi: Operación procesada por Codi'

        HSBC_DEBIT_SPECIFIC
      end

      def get_nu_debit_instructions
        <<~NU_DEBIT_SPECIFIC
          **NU DEBIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - Starts with 'Si solo tienes unos minutos, hicimos un resumen para ti'
          - Ends with 'Cómo está organizado tu dinero'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with 'Detalle de movimientos en tu cuenta' with these headers:
          - 'FECHA' (Date)
          - A period of days as the header of description (e.g., "Lunes 10", "Martes 11")
          - 'MONTO EN PESOS MEXICANOS' (Amount - (+) is income, (-) is expense)
          - Section ends with 'Con estos movimientos, tu saldo promedio del periodo fue de'

        NU_DEBIT_SPECIFIC
      end

      def get_rappicard_credit_instructions
        <<~RAPPICARD_CREDIT_SPECIFIC
          **RAPPICARD CREDIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - Starts with 'Resumen de movimientos'
          - Ends with 'Saldo Total'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction sections:

          **EXPENSES SECTION:**
          - Starts with 'Compras y cargos' with these headers:
            - 'Fecha' (Date)
            - 'Comercio' (Merchant)
            - 'Moneda extranjera' (Foreign Currency)
            - 'Importe cargos' (Charge Amount - this is expense (-))
          - Section ends with 'Total cargos del periodo'

          **INCOME SECTION:**
          - Starts with 'Pagos, devoluciones y bonificaciones' with these headers:
            - 'Fecha' (Date)
            - 'Detalle' (Detail)
            - 'Importe pagos' (Payment Amount - this is income (+))
          - Section ends with 'Total pagos del periodo'

        RAPPICARD_CREDIT_SPECIFIC
      end

      def get_scotiabank_credit_instructions
        <<~SCOTIABANK_CREDIT_SPECIFIC
          **SCOTIABANK CREDIT CARD SPECIFIC INSTRUCTIONS:**

          **FINANCIAL SUMMARY SECTION:**
          Look for these headers in the financial summary:
          - Starts with 'RESUMEN DE CARGOS Y ABONOS DEL PERIODO'
          - Ends with 'PAGO PARA NO GENERAR INTERESES'
          Extract opening balance, closing balance, and any other financial data

          **TRANSACTION SECTION:**
          Look for the transaction table that starts with 'CARGOS, ABONOS Y COMPRAS REGULARES (NO A MESES)' with these headers:
          - 'Fecha de la operación' (Operation Date)
          - 'Fecha de cargo' (Charge Date)
          - 'Descripción del movimiento' (Description)
          - 'Monto' (Amount - (+) is expense, (-) is income)
          - Section ends with 'Total cargos'

        SCOTIABANK_CREDIT_SPECIFIC
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


      def build_base_prompt(text, bank_name, account_type, bank_specific_section = "")
        sign_logic = get_sign_logic_for_account_type(account_type)

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

          #{bank_specific_section}

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
