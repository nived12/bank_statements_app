class Transactions::Importer < ApplicationService
  include Transactions::Concerns::ConceptSimilarity

  SPANISH_MONTHS = {
    "ENE" => "JAN", "FEB" => "FEB", "MAR" => "MAR", "ABR" => "APR",
    "MAY" => "MAY", "JUN" => "JUN", "JUL" => "JUL", "AGO" => "AUG",
    "SEP" => "SEP", "OCT" => "OCT", "NOV" => "NOV", "DIC" => "DEC"
  }.freeze

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
    category_id = if transaction_data["sub_category_id"].present?
      transaction_data["sub_category_id"]
    else
      transaction_data["category_id"]
    end

    PendingTransaction.create!(
      statement_file: statement_file,
      user: statement_file.user,
      bank_account: statement_file.bank_account,
      date: parse_date_safely(transaction_data["date"]),
      description: transaction_data["description"].to_s.squish,
      concept: derive_concept(transaction_data["description"]),
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
      concept: transaction.concept,
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
      # Support both string and symbol keys (from different processing paths)
      t = t.with_indifferent_access if t.respond_to?(:with_indifferent_access)

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
        concept: derive_concept(t["description"]),
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
      date_match = parse_date_safely(transaction["date"]) == duplicate.date
      amount_match = to_decimal(transaction["amount"]) == duplicate.amount
      date_match && amount_match && concept_similar_enough?(transaction, duplicate)
    end
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

  def derive_concept(description)
    return nil if description.blank?

    cleaned = description.to_s.dup

    # PII placeholder tokens inserted by upstream anonymization (e.g. ⟪PII:name:1⟫)
    cleaned.gsub!(/⟪PII:[^:]+:\d+⟫/, "")
    # SPEI routing prefixes (e.g. "SPEIBCO:0097161491BENEF:")
    cleaned.gsub!(/SPEIBCO:\d+BENEF:/, "")
    # Bank name + 3-digit routing codes (e.g. "HSBC 021", "BANORTE 072")
    cleaned.gsub!(/\b(?:HSBC|BANORTE|BBVA|SANTANDER|SCOTIABANK|BANAMEX|BAJIO)\s+\d{3}\b/i, "")
    # BNET transfer codes (e.g. "BNET 1234567")
    cleaned.gsub!(/\bBNET\s+\d+\b/i, "")
    # Long numeric sequences: CLABE (18 digits), account numbers, reference codes (10+ digits)
    cleaned.gsub!(/\b\d{10,}\b/, "")
    # Alphanumeric tracking codes (e.g. "AB123456", "MX987654")
    cleaned.gsub!(/\b[A-Z]{2,}\d{6,}\b/, "")
    cleaned.gsub!(/\b\d{6,}[A-Z]+\b/, "")
    # SPEI operation number prefix (e.g. "IN 4206032877")
    cleaned.gsub!(/\bIN\s+\d{7,}\b/, "")
    # Collapse extra whitespace
    cleaned.gsub!(/\s+/, " ")
    cleaned = cleaned.strip

    result = cleaned.presence || description.to_s.squish
    result[0, 60].rstrip
  end

  def parse_date_safely(date_value)
    return Date.current if date_value.blank?

    date_string = date_value.to_s.strip
    return Date.current if date_string.empty?

    # Handle common Mexican date formats
    case date_string
    when /^(\d{1,2})-([A-Z]{3})-(\d{2})$/
      # Format: "10-JUN-25" or "31-DIC-25"
      day, month, year = $1, $2, $3
      month = SPANISH_MONTHS.fetch(month, month)
      full_year = year.to_i < 50 ? "20#{year}" : "19#{year}"
      Date.parse("#{day}-#{month}-#{full_year}")
    when /^(\d{1,2})-([A-Z]{3})-(\d{4})$/
      # Format: "31-DIC-2025" or "10-JUN-2025"
      day, month, year = $1, $2, $3
      month = SPANISH_MONTHS.fetch(month, month)
      Date.parse("#{day}-#{month}-#{year}")
    when /^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/
      # Format: "10/06/25" or "10/06/2025"
      day, month, year = $1, $2, $3
      full_year = year.length == 2 ? (year.to_i < 50 ? "20#{year}" : "19#{year}") : year
      Date.parse("#{day}/#{month}/#{full_year}")
    else
      # Translate Spanish months before falling back to Date.parse
      translated = date_string.gsub(/\b(#{SPANISH_MONTHS.keys.join("|")})\b/, SPANISH_MONTHS)
      Date.parse(translated)
    end
  rescue Date::Error, ArgumentError => e
    # Log the error with more context and raise it to understand the root cause
    Rails.logger.error("Failed to parse date '#{date_string}': #{e.message}")
    Rails.logger.error("This indicates a problem with the date extraction in the parser")
    raise e
  end
end
