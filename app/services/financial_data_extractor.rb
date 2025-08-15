# Financial Data Extractor Service
# Extracts financial summary data from bank statement text using configuration patterns
class FinancialDataExtractor
  def initialize(bank_name)
    @bank_name = bank_name
    @config = BankStatementConfig.get_financial_extraction(bank_name)
    @statement_type = BankStatementConfig.get_statement_type(bank_name)
  end

  def extract_financial_data(text)
    return {} if @config.empty?

    {
      statement_type: @statement_type,
      initial_balance: extract_initial_balance(text),
      final_balance: extract_final_balance(text),
      period_dates: extract_period_dates(text),
      summary_totals: extract_summary_totals(text),
      interest_info: extract_interest_info(text),
      commission_info: extract_commission_info(text),
      statement_type_data: extract_type_specific_data(text)
    }.compact
  end

  private

  def extract_initial_balance(text)
    extract_amount_from_patterns(text, @config["initial_balance"] || [])
  end

  def extract_final_balance(text)
    extract_amount_from_patterns(text, @config["final_balance"] || [])
  end

  def extract_period_dates(text)
    extract_dates_from_patterns(text, @config["period_dates"] || [])
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
      return parse_amount(match[1]) if match
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
        results[key] = parse_date(match[1])
      end
    end
    results
  end

  def build_amount_regex(pattern)
    Regexp.new("#{Regexp.escape(pattern)}\\s*([\\d,]+\\.[\\d]{2})", Regexp::IGNORECASE)
  end

  def build_date_regex(pattern)
    Regexp.new("#{Regexp.escape(pattern)}\\s*([\\d]{1,2}[/-][\\w]{3,4}[/-]?[\\d]{2,4})", Regexp::IGNORECASE)
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

    formats = [
      "%d/%m/%Y", "%d-%m-%Y", "%d/%m/%y", "%d-%m-%y",
      "%d %b %Y", "%d %b %y", "%d-%b-%Y", "%d-%b-%y"
    ]

    formats.each do |format|
      begin
        return Date.strptime(date_str, format)
      rescue ArgumentError
        next
      end
    end
    nil
  end
end
