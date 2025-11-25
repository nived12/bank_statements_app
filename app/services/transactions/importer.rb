class Transactions::Importer < ApplicationService
  def initialize(statement_file, json: nil)
    super()
    @statement_file = statement_file
    @json = json || statement_file.parsed_json
    @user = statement_file.user
    @bank_account = statement_file.bank_account
  end

  def call
    return failure unless json.is_a?(Hash) && json["transactions"].is_a?(Array)

    # Detect duplicates first
    duplicates_result = Transactions::DuplicateDetector.call(statement_file, json: json)

    duplicates_found = false
    duplicate_transactions = []

    if duplicates_result.success? && duplicates_result.payload.any?
      # Store duplicates in PendingTransactions for user review
      store_duplicates_in_pending(duplicates_result.payload)
      duplicates_found = true

      # Collect existing transactions that are duplicates to exclude from import
      duplicate_transactions = duplicates_result.payload.flat_map { |group| group[:existing_transactions] }
    end

    # Import only non-duplicate transactions
    import_non_duplicate_transactions(user, bank_account, duplicate_transactions)
    success(duplicates_found: duplicates_found)
  end

  private

  attr_accessor :statement_file, :json, :user, :bank_account

  def store_duplicates_in_pending(duplicates)
    duplicates.each do |duplicate_group|
      statement_transaction = duplicate_group[:statement_transaction]
      existing_transactions = duplicate_group[:existing_transactions]

      # Store the statement transaction as pending
      store_pending_transaction(statement_transaction, :statement_file)

      # Store existing manual transactions as pending
      existing_transactions.each do |existing_transaction|
        store_pending_transaction_from_existing(existing_transaction)
      end
    end
  end

  def store_pending_transaction(transaction_data, source)
    category_id = transaction_data["sub_category_id"].present? ? transaction_data["sub_category_id"] : transaction_data["category_id"]

    PendingTransaction.create!(
      statement_file: statement_file,
      user: statement_file.user,
      bank_account: statement_file.bank_account,
      date: parse_date_safely(transaction_data["date"]),
      description: transaction_data["description"].to_s.squish,
      amount: to_decimal(transaction_data["amount"]),
      transaction_type: normalize_tx_type(transaction_data["transaction_type"], transaction_data["amount"]),
      category_id: category_id,
      merchant: transaction_data["merchant"],
      reference: transaction_data["reference"],
      confidence: normalize_confidence(transaction_data["confidence"]),
      category_confidence: normalize_confidence(transaction_data["category_confidence"]),
      transaction_type_confidence: normalize_confidence(transaction_data["transaction_type_confidence"]),
      source: source
    )
  end

  def store_pending_transaction_from_existing(transaction)
    PendingTransaction.create!(
      statement_file: statement_file,
      user: transaction.user,
      bank_account: transaction.bank_account,
      date: transaction.date,
      description: transaction.description,
      amount: transaction.amount,
      transaction_type: transaction.transaction_type,
      category_id: transaction.category_id,
      merchant: transaction.merchant,
      reference: transaction.reference,
      confidence: transaction.confidence,
      category_confidence: transaction.category_confidence,
      transaction_type_confidence: transaction.transaction_type_confidence,
      source: :manual
    )
  end

  def import_non_duplicate_transactions(user, bank_account, duplicate_transactions)
    json["transactions"].each do |t|
      # Skip if this transaction is a duplicate
      next if is_duplicate_transaction?(t, duplicate_transactions)

      # AI now returns category_id and sub_category_id directly
      # Use sub_category_id if present, otherwise use category_id
      # Allow nil for uncategorized transactions
      category_id = t["sub_category_id"].present? ? t["sub_category_id"] : t["category_id"]

      Transaction.create!(
        user: user,
        bank_account: bank_account,
        statement_file: statement_file,
      date: parse_date_safely(t["date"]),
      description: t["description"].to_s.squish,
      amount: to_decimal(t["amount"]),
      transaction_type: normalize_tx_type(t["transaction_type"], t["amount"]),
      category_id: category_id,
        merchant: t["merchant"],
        reference: t["reference"],
        confidence: normalize_confidence(t["confidence"]),
        category_confidence: normalize_confidence(t["category_confidence"]),
        transaction_type_confidence: normalize_confidence(t["transaction_type_confidence"]),
        source: :statement_file
      )
    end
  end

  def is_duplicate_transaction?(transaction, duplicate_transactions)
    duplicate_transactions.any? do |duplicate|
      # Use the same logic as DuplicateDetector for consistency
      date_match = parse_date_safely(transaction["date"]) == duplicate.date
      amount_match = to_decimal(transaction["amount"]) == duplicate.amount

      # For description, use similarity check like DuplicateDetector
      description_similarity = calculate_similarity(
        transaction["description"].to_s.squish,
        duplicate.description.to_s.squish
      )

      date_match && amount_match && description_similarity >= 0.2
    end
  end

  def calculate_similarity(desc1, desc2)
    return 1.0 if desc1 == desc2

    words1 = desc1.downcase.split(/\s+/)
    words2 = desc2.downcase.split(/\s+/)

    return 0.0 if words1.empty? || words2.empty?

    intersection = words1 & words2
    union = words1 | words2

    intersection.size.to_f / union.size
  end

  def to_decimal(v)
    return v.to_d.round(2) if v.is_a?(Numeric)

    v.to_s.tr(",", "").to_d.round(2)
  end

  def normalize_tx_type(v, amount)
    x = v.to_s.downcase.strip
    return x if %w[income fixed_expense variable_expense].include?(x)

    amt = to_decimal(amount).to_f
    amt < 0 ? "variable_expense" : "income"
  end

  def normalize_confidence(v)
    return if v.nil?

    v.to_f.clamp(0.0, 1.0)
  end

  def parse_date_safely(date_value)
    return Date.current if date_value.blank?

    date_string = date_value.to_s.strip
    return Date.current if date_string.empty?

    # Handle common Mexican date formats
    case date_string
    when /^(\d{1,2})-([A-Z]{3})-(\d{2})$/
      # Format: "10-JUN-25" -> "10-JUN-2025"
      day, month, year = $1, $2, $3
      full_year = year.to_i < 50 ? "20#{year}" : "19#{year}"
      Date.parse("#{day}-#{month}-#{full_year}")
    when /^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/
      # Format: "10/06/25" or "10/06/2025"
      day, month, year = $1, $2, $3
      full_year = year.length == 2 ? (year.to_i < 50 ? "20#{year}" : "19#{year}") : year
      Date.parse("#{day}/#{month}/#{full_year}")
    else
      # Try to parse the date as-is
      Date.parse(date_string)
    end
  rescue Date::Error, ArgumentError => e
    # Log the error with more context and raise it to understand the root cause
    Rails.logger.error("Failed to parse date '#{date_string}': #{e.message}")
    Rails.logger.error("This indicates a problem with the date extraction in the parser")
    raise e
  end
end
