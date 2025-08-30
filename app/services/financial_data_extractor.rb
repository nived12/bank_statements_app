# Financial Data Extractor Service
# Extracts financial summary data from bank statement text using configuration patterns
class FinancialDataExtractor < ApplicationService
  def initialize(bank_name)
    @bank_name = bank_name
    @config = BankStatementConfig.get_financial_extraction(bank_name)
    @statement_type = BankStatementConfig.get_statement_type(bank_name)
  end

  def extract_financial_data(text)
    return {} if @config.empty?

    result = {
      statement_type: @statement_type,
      initial_balance: extract_initial_balance(text),
      final_balance: extract_final_balance(text),
      period_dates: extract_period_dates(text),
      summary_totals: extract_summary_totals(text),
      interest_info: extract_interest_info(text),
      commission_info: extract_commission_info(text),
      statement_type_data: extract_type_specific_data(text)
    }.compact

    result
  end

  private

  def extract_initial_balance(text)
    result = extract_amount_from_patterns(text, @config["initial_balance"] || [])

    # Fallback to common BBVA patterns if configured patterns fail
    if result.nil? && @bank_name.to_s.downcase.include?("bbva")
      result = extract_bbva_fallback_initial_balance(text)
    end

    result
  end

  def extract_final_balance(text)
    result = extract_amount_from_patterns(text, @config["final_balance"] || [])

    # Fallback to common BBVA patterns if configured patterns fail
    if result.nil? && @bank_name.to_s.downcase.include?("bbva")
      result = extract_bbva_fallback_final_balance(text)
    end

    result
  end

  def extract_period_dates(text)
    result = extract_dates_from_patterns(text, @config["period_dates"] || [])

    # Fallback to common BBVA patterns if configured patterns fail
    if result.empty? && @bank_name.to_s.downcase.include?("bbva")
      result = extract_bbva_fallback_period_dates(text)
    end

    result
  end

  def extract_summary_totals(text)
    extract_amounts_from_patterns(text, @config["summary_totals"] || [])
  end

  def extract_interest_info(text)
    extract_amounts_from_patterns(text, @config["interest_info"] || [])
  end

  def extract_commission_info(text)
    extract_amounts_from_patterns(text, @config["commission_info"] || [])
  end

  def extract_type_specific_data(text)
    case @statement_type
    when "savings"
      extract_savings_data(text)
    when "credit"
      extract_credit_data(text)
    when "payroll"
      extract_payroll_data(text)
    else
      {}
    end
  end

  def extract_savings_data(text)
    {
      "average_balance" => extract_average_balance(text),
      "total_deposits" => extract_total_deposits(text),
      "total_withdrawals" => extract_total_withdrawals(text),
      "interest_earned" => extract_interest_earned(text)
    }.compact
  end

  def extract_credit_data(text)
    {
      "credit_limit" => extract_credit_limit(text),
      "available_credit" => extract_available_credit(text),
      "payment_to_avoid_interest" => extract_payment_to_avoid_interest(text),
      "minimum_payment" => extract_minimum_payment(text),
      "total_charges" => extract_total_charges(text),
      "total_payments" => extract_total_payments(text),
      "interest_charged" => extract_interest_charged(text)
    }.compact
  end

  def extract_payroll_data(text)
    {
      "total_deposits" => extract_total_deposits(text),
      "total_withdrawals" => extract_total_withdrawals(text),
      "interest_earned" => extract_interest_earned(text)
    }.compact
  end

  def extract_amount_from_patterns(text, patterns)
    patterns.each do |pattern|
      regex = build_amount_regex(pattern)

      match = text.match(regex)
      if match
        amount = parse_amount(match[1])
        return amount
      end
    end

    nil
  end

  def extract_amounts_from_patterns(text, patterns)
    results = {}
    patterns.each do |pattern|
      regex = build_amount_regex(pattern)
      match = text.match(regex)
      if match
        key = pattern.gsub(/[:\s]+/, "_").downcase
        results[key] = parse_amount(match[1])
      end
    end
    results
  end

  def extract_dates_from_patterns(text, patterns)
    results = {}

    patterns.each do |pattern|
      regex = build_date_regex(pattern)

      match = text.match(regex)
      if match
        key = pattern.gsub(/[:\s]+/, "_").downcase
        date = parse_date(match[1])
        results[key] = date
      end
    end

    results
  end

  # BBVA-specific fallback patterns
  def extract_bbva_fallback_initial_balance(text)
    # Common BBVA initial balance patterns
    patterns = [
      /Saldo\s+Inicial\s*:?\s*([\d,]+\.?\d*)/i,
      /Saldo\s+de\s+Liquidación\s+Inicial\s*:?\s*([\d,]+\.?\d*)/i,
      /Saldo\s+Anterior\s*:?\s*([\d,]+\.?\d*)/i,
      /Balance\s+Inicial\s*:?\s*([\d,]+\.?\d*)/i,
      /Saldo\s+Inicial\s+([\d,]+\.?\d*)/i,
      /Saldo\s+Anterior\s+([\d,]+\.?\d*)/i
    ]

    patterns.each do |pattern|
      match = text.match(pattern)
      if match
        amount = parse_amount(match[1])
        return amount
      end
    end

    nil
  end

  def extract_bbva_fallback_final_balance(text)
    # Common BBVA final balance patterns
    patterns = [
      /Saldo\s+Final\s*:?\s*([\d,]+\.?\d*)/i,
      /Saldo\s+de\s+Liquidación\s*:?\s*([\d,]+\.?\d*)/i,
      /Saldo\s+Actual\s*:?\s*([\d,]+\.?\d*)/i,
      /Balance\s+Final\s*:?\s*([\d,]+\.?\d*)/i,
      /Saldo\s+Final\s+([\d,]+\.?\d*)/i,
      /Saldo\s+Actual\s+([\d,]+\.?\d*)/i
    ]

    patterns.each do |pattern|
      match = text.match(pattern)
      if match
        amount = parse_amount(match[1])
        return amount
      end
    end

    nil
  end

  def extract_bbva_fallback_period_dates(text)
    results = {}

    # Common BBVA period date patterns
    start_patterns = [
      /Periodo\s*:?\s*([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Del\s*:?\s*([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Desde\s*:?\s*([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Periodo\s+([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Del\s+([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i
    ]

    end_patterns = [
      /Al\s*:?\s*([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Hasta\s*:?\s*([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Fecha\s+de\s+Corte\s*:?\s*([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Al\s+([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      /Hasta\s+([\d]{1,2}[\/\-][\w]{3,4}[\/\-]?[\d]{2,4})/i,
      # BBVA specific: "01/JUN/2025 al 30/JUN/2025"
      /(\d{1,2}\/\w{3,4}\/\d{2,4})\s+al\s+(\d{1,2}\/\w{3,4}\/\d{2,4})/i
    ]

    # Special handling for BBVA format: "01/JUN/2025 al 30/JUN/2025"
    bbva_period_match = text.match(/(\d{1,2}\/\w{3,4}\/\d{2,4})\s+al\s+(\d{1,2}\/\w{3,4}\/\d{2,4})/i)
    if bbva_period_match
      start_date = parse_date(bbva_period_match[1])
      end_date = parse_date(bbva_period_match[2])

      if start_date && end_date
        Rails.logger.info("Successfully parsed BBVA period dates: start=#{start_date}, end=#{end_date}")
        results["start"] = start_date
        results["end"] = end_date
        return results
      else
        Rails.logger.warn("Failed to parse BBVA period dates: start=#{start_date}, end=#{end_date}")
      end
    end

    # Try to find start date
    start_patterns.each do |pattern|
      match = text.match(pattern)
      if match
        date = parse_date(match[1])
        if date
          Rails.logger.info("Successfully parsed start date: #{date}")
          results["start"] = date
          break
        else
          Rails.logger.warn("Failed to parse start date: #{match[1]}")
        end
      end
    end

    # Try to find end date
    end_patterns.each do |pattern|
      match = text.match(pattern)
      if match
        date = parse_date(match[1])
        if date
          Rails.logger.info("Successfully parsed end date: #{date}")
          results["end"] = date
          break
        else
          Rails.logger.warn("Failed to parse end date: #{match[1]}")
        end
      end
    end

    results
  end

  def build_amount_regex(pattern)
    # More flexible amount pattern that handles various formats
    # Allow for optional spaces, currency symbols, and various amount formats
    amount_pattern = "\\s*[\\$€£]?\\s*([\\d,]+\\.[\\d]{2}|[\\d,]+|[\\d]+\\.[\\d]{2})"
    Regexp.new("#{Regexp.escape(pattern)}#{amount_pattern}", Regexp::IGNORECASE)
  end

  def build_date_regex(pattern)
    # More flexible date pattern that handles various formats
    # Handle BBVA format: "01/JUN/2025 al 30/JUN/2025"
    date_pattern = "\\s*([\\d]{1,2}[\\/\\-][\\w]{3,4}[\\/\\-]?[\\d]{2,4}|[\\d]{1,2}\\s+(?:de\\s+)?(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\\s+(?:de\\s+)?[\\d]{4})"
    Regexp.new("#{Regexp.escape(pattern)}#{date_pattern}", Regexp::IGNORECASE)
  end

  def extract_average_balance(text)
    match = text.match(/Saldo Promedio\s+([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_total_deposits(text)
    match = text.match(/(?:Total )?Depósitos\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_total_withdrawals(text)
    match = text.match(/(?:Total )?Retiros\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_interest_earned(text)
    match = text.match(/Intereses\s+(?:Ganados|Devengados)\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_credit_limit(text)
    match = text.match(/Línea\s+de\s+Crédito\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_available_credit(text)
    match = text.match(/Crédito\s+Disponible\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_payment_to_avoid_interest(text)
    match = text.match(/Pago\s+para\s+No\s+Pagar\s+Intereses\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_minimum_payment(text)
    match = text.match(/Pago\s+Mínimo\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_total_charges(text)
    match = text.match(/(?:Total )?Cargos\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_total_payments(text)
    match = text.match(/(?:Total )?Pagos\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def extract_interest_charged(text)
    match = text.match(/Intereses\s+Cobrados\s*:?\s*([\d,]+\.\d{2})/i)
    parse_amount(match[1]) if match
  end

  def parse_amount(amount_str)
    return nil unless amount_str
    BigDecimal(amount_str.gsub(",", ""))
  rescue ArgumentError, TypeError
    nil
  end

  def parse_date(date_str)
    return nil unless date_str

    # First, try to handle Spanish month abbreviations
    spanish_month_map = {
      "ENE" => "01", "FEB" => "02", "MAR" => "03", "ABR" => "04",
      "MAY" => "05", "JUN" => "06", "JUL" => "07", "AGO" => "08",
      "SEP" => "09", "OCT" => "10", "NOV" => "11", "DIC" => "12"
    }

    # Check if the date string contains Spanish month abbreviations
    spanish_month_map.each do |abbr, month_num|
      if date_str.upcase.include?(abbr)
        # Replace Spanish abbreviation with month number
        normalized_date = date_str.gsub(/#{abbr}/i, month_num)

        # Try to parse the normalized date
        formats = [
          "%d/%m/%Y", "%d-%m-%Y", "%d/%m/%y", "%d-%m-%y"
        ]

        formats.each do |format|
          begin
            parsed_date = Date.strptime(normalized_date, format)
            return parsed_date
          rescue ArgumentError
          end
        end
      end
    end

    # Fallback to original formats (including English month abbreviations)
    formats = [
      "%d/%m/%Y", "%d-%m-%Y", "%d/%m/%y", "%d-%m-%y",
      "%d %b %Y", "%d %b %y", "%d-%b-%Y", "%d-%b-%y"
    ]

    formats.each do |format|
      begin
        parsed_date = Date.strptime(date_str, format)
        return parsed_date
      rescue ArgumentError
      end
    end

    Rails.logger.warn("Failed to parse date: #{date_str}")
    nil
  end
end
