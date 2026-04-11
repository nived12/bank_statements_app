class Transactions::DuplicateDetector < ApplicationService
  include Transactions::Concerns::ConceptSimilarity

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

    candidates = Transaction.where(
      user: @user,
      bank_account: @bank_account,
      date: date,
      amount: amount
    ).where.not(source: :bank_api)  # Look for manual and statement_file transactions

    candidates.select { |transaction| concept_similar_enough?(transaction_data, transaction) }
  end

  def to_decimal(v)
    return v.to_d.round(2) if v.is_a?(Numeric)

    v.to_s.tr(",", "").to_d.round(2)
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
