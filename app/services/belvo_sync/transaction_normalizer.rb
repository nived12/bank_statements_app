class BelvoSync::TransactionNormalizer < ApplicationService
  include Transactions::Concerns::ConceptSimilarity

  def initialize(belvo_transaction:, bank_account:)
    super()
    @bt = belvo_transaction
    @bank_account = bank_account
    @user = bank_account.user
  end

  def call
    attrs = {
      user: @user,
      bank_account: @bank_account,
      belvo_transaction_id: @bt["id"],
      date: parse_date(@bt["value_date"] || @bt["accounting_date"]),
      description: (@bt["description"] || "").squish,
      concept: derive_concept(@bt["description"]),
      amount: normalize_amount,
      transaction_type: map_transaction_type,
      merchant: extract_merchant,
      reference: @bt["reference"],
      source: :bank_api,
      confidence: 0.95,
      transaction_type_confidence: 0.9
    }

    apply_category_rules(attrs)
    success(attrs)
  end

  private

  def normalize_amount
    @bt["amount"].to_d.round(2)
  end

  def map_transaction_type
    case @bt["type"].to_s.upcase
    when "INFLOW"
      "income"
    when "OUTFLOW"
      "variable_expense"
    else
      @bt["amount"].to_d >= 0 ? "income" : "variable_expense"
    end
  end

  def extract_merchant
    @bt.dig("merchant", "name") || @bt.dig("merchant", "merchant_name")
  end

  def derive_concept(description)
    return nil if description.blank?

    cleaned = description.to_s.dup
    # CLABE numbers and long numeric sequences
    cleaned.gsub!(/\b\d{10,}\b/, "")
    # SPEI routing prefixes
    cleaned.gsub!(/SPEIBCO:\d+BENEF:/, "")
    # Bank routing codes
    cleaned.gsub!(/\b(?:HSBC|BANORTE|BBVA|SANTANDER|SCOTIABANK|BANAMEX|BAJIO)\s+\d{3}\b/i, "")
    # BNET transfer codes
    cleaned.gsub!(/\bBNET\s+\d+\b/i, "")
    # Alphanumeric tracking codes
    cleaned.gsub!(/\b[A-Z]{2,}\d{6,}\b/, "")
    cleaned.gsub!(/\b\d{6,}[A-Z]+\b/, "")
    # SPEI operation number prefix
    cleaned.gsub!(/\bIN\s+\d{7,}\b/, "")
    cleaned.gsub!(/\s+/, " ")
    cleaned = cleaned.strip

    result = cleaned.presence || description.to_s.squish
    result[0, 60].rstrip
  end

  def parse_date(date_value)
    return Date.current if date_value.blank?

    Date.parse(date_value.to_s)
  rescue Date::Error, ArgumentError
    Date.current
  end

  def apply_category_rules(attrs)
    tx_hash = { "description" => attrs[:description] }
    result = CategoryRules::Matcher.call(user: @user, transactions: [tx_hash])

    if result.success? && result.payload[:matched].any?
      matched = result.payload[:matched].first
      attrs[:category_id] = matched["sub_category_id"] || matched["category_id"]
      attrs[:category_confidence] = matched["category_confidence"]
    end
  end
end
