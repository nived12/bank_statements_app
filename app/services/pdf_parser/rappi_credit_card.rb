# app/services/pdf_parser/rappi_credit_card.rb
module PdfParser
  class RappiCreditCard < Base
    include MerchantExtraction

    # Rappi uses ISO date format: YYYY-MM-DD
    DATE_PATTERN = /^\s*(\d{4}-\d{2}-\d{2})/

    # Amount pattern: $X,XXX.XX or $XXX.XX
    AMOUNT_PATTERN = /\$\s*([\d,]+\.\d{2})\s*$/

    # Section markers
    TRANSACTIONS_START = /Compras\s*y\s*cargos/i
    TRANSACTIONS_END = /Total\s*cargos\s*del\s*periodo/i
    PAYMENTS_START = /Pagos,?\s*devoluciones\s*y\s*bonificaciones/i
    PAYMENTS_END = /Total\s*pagos\s*del\s*periodo/i

    # Skip patterns
    SKIP_PATTERNS = [
      /^Fecha/i,
      /^Movimientos\s+tarjeta/i,
      /^Subtotal/i,
      /^Total/i,
      /Moneda\s+extranjera/i,
      /Importe\s+cargos/i,
      /Importe\s+pagos/i,
      /^\s*$/
    ].freeze

    def parse(text)
      lines = text.to_s.split(/\r?\n/).map(&:strip).compact_blank

      transactions = []

      # Parse charges (purchases) section
      charge_lines = extract_section(lines, TRANSACTIONS_START, TRANSACTIONS_END)
      charges = parse_transactions(charge_lines, :expense)
      transactions.concat(charges)

      # Parse payments section
      payment_lines = extract_section(lines, PAYMENTS_START, PAYMENTS_END)
      payments = parse_transactions(payment_lines, :payment)
      transactions.concat(payments)

      # Extract financial summary
      financial_summary = extract_financial_summary(lines)

      {
        "extraction_source" => "deterministic_parser",
        "transactions" => transactions,
        "opening_balance" => financial_summary[:opening_balance],
        "closing_balance" => financial_summary[:closing_balance],
        "financial_summaries" => financial_summary[:summary] ? [financial_summary[:summary]] : []
      }
    end

    private

    def extract_section(lines, start_pattern, end_pattern)
      section_lines = []
      in_section = false

      lines.each do |line|
        if line.match?(start_pattern)
          in_section = true
          next
        end

        break if in_section && line.match?(end_pattern)

        section_lines << line if in_section
      end

      section_lines
    end

    def parse_transactions(lines, transaction_type)
      transactions = []
      pending_merchant = nil

      lines.each_with_index do |line, idx|
        # Skip header and summary lines
        next if SKIP_PATTERNS.any? { |pattern| line.match?(pattern) }

        date_match = line.match(DATE_PATTERN)

        # If no date, this might be a merchant line for foreign purchase
        unless date_match
          # Check if this looks like a standalone merchant name
          # (text-only line that's not a header/skip pattern)
          if line.strip.length > 3 && !line.match?(/\d/)
            pending_merchant = line.strip
          end
          next
        end

        # Extract the last amount in the line (Importe cargos column)
        amounts = line.scan(/\$?\s*([\d,]+\.\d{2})/)
        next if amounts.empty?

        # For charges with USD conversion, there are multiple amounts
        # The last amount is always the MXN charge
        amount_str = amounts.last[0]
        amount = parse_decimal(amount_str)
        next unless amount

        # Extract description (everything between date and amounts)
        description = extract_description(line, date_match[0])

        # If description is about foreign purchase and we have a pending merchant, use it
        if description.match?(/Compra\s+en\s+el\s+Extranjero/i) && pending_merchant
          description = pending_merchant
        end

        # Clear pending merchant after use
        pending_merchant = nil

        # Skip lines that are just empty
        next if description.blank?

        # Determine transaction type and sign
        amount_value, type = determine_amount_and_type(amount.to_f, transaction_type)

        merchant = extract_merchant(description)

        transactions << {
          "date" => date_match[1],
          "description" => description,
          "amount" => sprintf("%.2f", amount_value),
          "transaction_type" => type,
          "merchant" => merchant,
          "reference" => nil,
          "raw_text" => line
        }
      end

      transactions
    end

    def extract_description(line, date)
      # Remove date from line
      desc = line.sub(date, "")

      # Remove all amount patterns (including USD amounts)
      desc = desc.gsub(/\$?\s*[\d,]+\.\d{2}/, "")

      # Remove USD indicator
      desc = desc.gsub(/USD\s*/, "")

      # Remove foreign purchase indicator
      desc = desc.gsub(/Compra\s+en\s+el\s+Extranjero.*?de\s+cambio\s+\$?[\d.]+/i, "")

      # Clean up whitespace
      desc.gsub(/\s+/, " ").strip
    end

    def determine_amount_and_type(amount, section_type)
      if section_type == :expense
        # Credit card charges are expenses (negative in our system)
        [-amount.abs, "variable_expense"]
      else
        # Payments, bonifications, and returns are income (positive in our system)
        [amount.abs, "income"]
      end
    end

    def extract_financial_summary(lines)
      summary = {
        "statement_type" => "credit",
        "bank_name" => "Rappi"
      }

      opening_balance = nil
      closing_balance = nil
      payment_to_avoid_interest = nil
      minimum_payment = nil
      credit_limit = nil
      available_credit = nil
      cashback_earned = nil

      lines.each do |line|
        standardized = line.gsub(/\s+/, "").downcase

        # Opening balance (previous period balance)
        if standardized.include?("saldoalcortedelperiodoanterior") ||
           standardized.include?("adeudodelperiodoanterior")
          if match = line.match(/\+?\s*\$?\s*([\d,]+\.\d{2})/)
            opening_balance = match[1].gsub(",", "").to_f
          end
        end

        # Closing balance (total balance)
        if standardized.include?("saldototal") && !standardized.include?("periodo")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            closing_balance = match[1].gsub(",", "").to_f
          end
        end

        # Payment to avoid interest
        if standardized.include?("pagoparanogenerarintereses")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            payment_to_avoid_interest = match[1].gsub(",", "").to_f
          end
        end

        # Minimum payment
        if standardized.include?("pagomínimo") || standardized.include?("pagominimo")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            minimum_payment = match[1].gsub(",", "").to_f
          end
        end

        # Credit limit
        if standardized.include?("líneadecrédito") || standardized.include?("lineadecredito")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            credit_limit = match[1].gsub(",", "").to_f
          end
        end

        # Available credit
        if standardized.include?("créditodisponible") || standardized.include?("creditodisponible")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            available_credit = match[1].gsub(",", "").to_f
          end
        end

        # Cashback
        if standardized.include?("cashback") && standardized.include?("ganado")
          if match = line.match(/\$?\s*([\d,]+\.\d{2})/)
            cashback_earned = match[1].gsub(",", "").to_f
          end
        end
      end

      summary["opening_balance"] = opening_balance
      summary["closing_balance"] = closing_balance
      summary["payment_to_avoid_interest"] = payment_to_avoid_interest
      summary["minimum_payment"] = minimum_payment
      summary["credit_limit"] = credit_limit
      summary["available_credit"] = available_credit
      summary["cashback_earned"] = cashback_earned if cashback_earned

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: summary
      }
    end
  end
end
