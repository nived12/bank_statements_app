class Transactions::DuplicateDetector < ApplicationService
  SIMILARITY_THRESHOLD = 0.2 # 20% similarity threshold

  def initialize(statement_file, json: nil)
    super()
    @statement_file = statement_file
    @user = statement_file.user
    @bank_account = statement_file.bank_account
    @json = json || statement_file.parsed_json
  end

  def call
    return success([]) if @json["transactions"].blank?

    duplicates_found = []

    @json["transactions"].each do |transaction_data|
      # Check for similar duplicates (description similarity)
      similar_duplicates = find_similar_duplicates(transaction_data)

      if similar_duplicates.any?
        duplicates_found << {
          statement_transaction: transaction_data,
          existing_transactions: similar_duplicates
        }
      end
    end

    success(duplicates_found)
  end

  private

  def find_similar_duplicates(transaction_data)
    date = parse_date_safely(transaction_data["date"])
    amount = to_decimal(transaction_data["amount"])
    description = transaction_data["description"].to_s.squish

    # Find transactions with same user, bank_account, date, amount
    candidates = Transaction.where(
      user: @user,
      bank_account: @bank_account,
      date: date,
      amount: amount,
      source: :manual  # Only look for manual transactions
    )

    # Filter by description similarity
    candidates.select do |transaction|
      similarity = calculate_similarity(description, transaction.description)
      similarity >= SIMILARITY_THRESHOLD
    end
  end

  def calculate_similarity(desc1, desc2)
    return 0.0 if desc1.blank? || desc2.blank?

    # Normalize descriptions
    normalized1 = normalize_description(desc1)
    normalized2 = normalize_description(desc2)

    # Calculate Jaccard similarity
    words1 = normalized1.split(/\s+/).to_set
    words2 = normalized2.split(/\s+/).to_set

    intersection = words1 & words2
    union = words1 | words2

    return 0.0 if union.empty?

    intersection.size.to_f / union.size
  end

  def normalize_description(description)
    description.to_s.downcase
               .gsub(/[^\w\s]/, " ") # Replace punctuation with spaces
               .gsub(/\s+/, " ")      # Normalize whitespace
               .strip
  end

  def to_decimal(v)
    return v.to_d if v.is_a?(Numeric)
    v.to_s.tr(",", "").to_d
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
    Rails.logger.error("Failed to parse date '#{date_string}': #{e.message}")
    Date.current
  end
end
