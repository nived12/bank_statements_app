# app/services/pdf_parser/rappi_credit_card.rb
module PdfParser
  class RappiCreditCard < Base
    include MerchantExtraction

    DATE_PATTERN = /^\s*(\d{4}-\d{2}-\d{2})/
    CHARGES_START = /Compras\s*y\s*cargos/i
    CHARGES_END = /Total\s*cargos\s*del\s*periodo/i
    PAYMENTS_START = /Pagos,?\s*devoluciones\s*y\s*bonificaciones/i
    PAYMENTS_END = /Total\s*pagos\s*del\s*periodo/i

    SKIP_PATTERNS = [
      /^Fecha/i, /^Movimientos\s+tarjeta/i, /^Subtotal/i, /^Total/i,
      /Moneda\s+extranjera/i, /Importe\s+cargos/i, /Importe\s+pagos/i, /^\s*$/
    ].freeze

    def parse(text)
      lines = split_lines(text)

      transactions = []
      transactions.concat(parse_transactions(extract_section(lines, CHARGES_START, CHARGES_END), :expense))
      transactions.concat(parse_transactions(extract_section(lines, PAYMENTS_START, PAYMENTS_END), :payment))

      summary_data = extract_financial_summary(lines)
      build_result(
        transactions: transactions,
        opening_balance: summary_data[:opening_balance],
        closing_balance: summary_data[:closing_balance],
        summary: summary_data[:summary]
      )
    end

    private

    def parse_transactions(lines, section_type)
      transactions = []
      pending_merchant = nil

      lines.each do |line|
        next if should_skip_line?(line, SKIP_PATTERNS)

        date_match = line.match(DATE_PATTERN)
        unless date_match
          pending_merchant = line.strip if line.strip.length > 3 && !line.match?(/\d/)
          next
        end

        amounts = line.scan(/\$?\s*([\d,]+\.\d{2})/)
        next if amounts.empty?

        amount = parse_decimal(amounts.last[0])
        next unless amount

        description = extract_description(line, date_match[0])
        description = pending_merchant if description.match?(/Compra\s+en\s+el\s+Extranjero/i) && pending_merchant
        pending_merchant = nil
        next if description.blank?

        amount_value, type = section_type == :expense ? [-amount.abs, "variable_expense"] : [amount.abs, "income"]

        transactions << build_transaction(
          date: date_match[1],
          description: description,
          amount: amount_value,
          transaction_type: type,
          merchant: extract_merchant(description),
          raw_text: line
        )
      end

      transactions
    end

    def extract_description(line, date)
      line.sub(date, "")
        .gsub(/\$?\s*[\d,]+\.\d{2}/, "")
        .gsub(/USD\s*/, "")
        .gsub(/Compra\s+en\s+el\s+Extranjero.*?de\s+cambio\s+\$?[\d.]+/i, "")
        .gsub(/\s+/, " ")
        .strip
    end

    def extract_financial_summary(lines)
      opening_balance = closing_balance = nil
      extras = {}

      lines.each do |line|
        normalized = line.gsub(/\s+/, "").downcase

        if normalized.include?("saldoalcortedelperiodoanterior") || normalized.include?("adeudodelperiodoanterior")
          opening_balance ||= extract_amount_from_text(line)
        elsif normalized.include?("saldototal") && !normalized.include?("periodo")
          closing_balance ||= extract_amount_from_text(line)
        elsif normalized.include?("pagoparanogenerarintereses")
          extras[:payment_to_avoid_interest] ||= extract_amount_from_text(line)
        elsif normalized.include?("pagomínimo") || normalized.include?("pagominimo")
          extras[:minimum_payment] ||= extract_amount_from_text(line)
        elsif normalized.include?("líneadecrédito") || normalized.include?("lineadecredito")
          extras[:credit_limit] ||= extract_amount_from_text(line)
        elsif normalized.include?("créditodisponible") || normalized.include?("creditodisponible")
          extras[:available_credit] ||= extract_amount_from_text(line)
        elsif normalized.include?("cashback") && normalized.include?("ganado")
          extras[:cashback_earned] ||= extract_amount_from_text(line)
        end
      end

      {
        opening_balance: opening_balance,
        closing_balance: closing_balance,
        summary: build_credit_summary(
          bank_name: "Rappi",
          opening_balance: opening_balance,
          closing_balance: closing_balance,
          **extras
        )
      }
    end
  end
end
