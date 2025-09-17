class Transactions::Importer < ApplicationService
  def initialize(statement_file, json: nil)
    super()
    @statement_file = statement_file
    @json = json || statement_file.parsed_json
  end

  def call
    return failure unless @json.is_a?(Hash) && @json["transactions"].is_a?(Array)

    user = @statement_file.user
    bank_account = @statement_file.bank_account

    @json["transactions"].each do |t|
      # AI now returns category_id and sub_category_id directly
      # Use sub_category_id if present, otherwise use category_id
      # Fall back to uncategorized if no category is provided
      category_id = t["sub_category_id"].present? ? t["sub_category_id"] : t["category_id"]
      category_id ||= user.categories.find_by(name: "Sin Categorizar")&.id

      Transaction.create!(
        user: user,
        bank_account: bank_account,
        statement_file: @statement_file,
        date: parse_date_safely(t["date"]),
        description: t["description"].to_s,
        amount: to_decimal(t["amount"]),
        transaction_type: normalize_tx_type(t["transaction_type"], t["amount"]),
        bank_entry_type: normalize_bank_type(t["bank_entry_type"]),
        category_id: category_id,
        merchant: t["merchant"],
        reference: t["reference"]
      )
    end

    success
  end

  private


  def to_decimal(v)
    return v.to_d if v.is_a?(Numeric)
    v.to_s.tr(",", "").to_d
  end

  def normalize_tx_type(v, amount)
    x = v.to_s.downcase.strip
    return x if %w[income fixed_expense variable_expense].include?(x)
    amt = to_decimal(amount).to_f
    amt < 0 ? "variable_expense" : "income"
  end

  def normalize_bank_type(v)
    x = v.to_s.downcase.strip
    return "credit" if %w[credit cr].include?(x)
    return "debit"  if %w[debit dr].include?(x)
    nil
  end

  def parse_date_safely(date_value)
    return Date.current if date_value.blank?

    date_string = date_value.to_s.strip
    return Date.current if date_string.empty?

    # Try to parse the date
    Date.parse(date_string)
  rescue Date::Error, ArgumentError => e
    # Log the error with more context and raise it to understand the root cause
    Rails.logger.error("Failed to parse date '#{date_string}': #{e.message}")
    Rails.logger.error("This indicates a problem with the date extraction in the parser")
    raise e
  end
end
