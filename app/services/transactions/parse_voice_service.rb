# frozen_string_literal: true

class Transactions::ParseVoiceService < ApplicationService
  VALID_TRANSACTION_TYPES = %w[income fixed_expense variable_expense transfer_in transfer_out].freeze

  def initialize(text:, user:)
    super()
    @text = text
    @user = user
  end

  def call
    categories = user_categories
    accounts = user_bank_accounts
    prompt = build_prompt(categories, accounts)

    raw = Ai::Client.new.chat(prompt)
    parsed = parse_json(raw[:text])
    return failure("AI returned unparseable response") if parsed.nil?

    success(build_result(parsed, categories, accounts))
  rescue StandardError => e
    Rails.logger.error("ParseVoiceService error: #{e.message}")
    failure("AI parsing failed")
  end

  private

  attr_reader :text, :user

  def user_categories
    Category.where(user_id: [user.id, nil])
            .select(:id, :name)
            .map { |c| { id: c.id, name: c.name } }
  end

  def user_bank_accounts
    user.bank_accounts.kept.includes(:bank).map do |a|
      { id: a.id, name: a.display_name, bank: a.bank&.name, type: a.account_type }
    end
  end

  def build_prompt(categories, accounts)
    <<~PROMPT
      You are a financial transaction parser for Mexican users.
      Parse the voice input and return ONLY a valid JSON object.

      CRITICAL: Keep "description" and "merchant_name" separate:
      • "description" = WHAT was purchased or the PURPOSE of the transaction.
        Use the item name if mentioned (e.g. "Papas Sabritas", "Café americano", "Gasolina", "Renta").
        If only a store is mentioned with no specific item, use a short generic like "Compra" or the category name.
        NEVER put the store name in description.
      • "merchant_name" = the STORE or BUSINESS name (e.g. "Oxxo", "Starbucks", "Walmart"), or null if none mentioned.

      JSON fields:
      - "amount": positive float (absolute value)
      - "description": what was bought / transaction purpose (NOT the store name)
      - "merchant_name": store or business name, or null
      - "transaction_type": one of "income", "fixed_expense", "variable_expense", "transfer_in", "transfer_out"
      - "date": "YYYY-MM-DD" if a date is mentioned, else null
      - "category_id": best-matching id from: #{categories.to_json} — or null
      - "bank_account_id": best-matching id from: #{accounts.to_json}
        Matching rules:
        • "TDC" / "tarjeta de crédito" / "crédito" → account_type "credit"
        • "TDD" / "débito" / "cuenta" / "tarjeta de débito" → account_type "debit"
        • "efectivo" / "cash" → account_type "cash"
        • Bank aliases (fuzzy): bbva=bancomer, nu=nubank, banamex=citibanamex, hey=hey banco
        • When only a bank name is mentioned without type (e.g. "mi tarjeta de BBVA"), match any account
          whose bank name contains that bank name regardless of account_type.
        • Return null only if no bank or account is mentioned at all.
      - "confidence": float 0.0–1.0

      Voice input: "#{text}"

      Return ONLY the JSON object. No markdown, no explanation, no code fences.
    PROMPT
  end

  def parse_json(raw_text)
    return nil if raw_text.blank?

    cleaned = raw_text.strip.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip
    JSON.parse(cleaned)
  rescue JSON::ParserError
    nil
  end

  def build_result(parsed, categories, accounts)
    amount = parsed["amount"].to_f.abs
    transaction_type = parsed["transaction_type"].to_s
    transaction_type = "variable_expense" unless VALID_TRANSACTION_TYPES.include?(transaction_type)
    confidence = parsed["confidence"].to_f.clamp(0.0, 1.0)

    raw_date = parsed["date"].to_s.strip
    date = begin
      Date.parse(raw_date).to_s if raw_date.present?
    rescue ArgumentError, TypeError
      nil
    end

    category_id = parsed["category_id"].to_i
    valid_category_ids = categories.map { |c| c[:id] }
    category_suggestion = if valid_category_ids.include?(category_id)
      cat = categories.find { |c| c[:id] == category_id }
      { id: cat[:id], name: cat[:name] }
    end

    valid_account_ids = accounts.map { |a| a[:id] }
    raw_account_id = parsed["bank_account_id"].to_i
    bank_account_id = valid_account_ids.include?(raw_account_id) ? raw_account_id : nil

    merchant = parsed["merchant_name"].to_s.strip.presence

    {
      amount: amount,
      description: parsed["description"].to_s.strip,
      merchant: merchant,
      bank_account_id: bank_account_id,
      transaction_type: transaction_type,
      date: date,
      category_suggestion: category_suggestion,
      confidence: confidence,
      transcript: text.to_s.slice(0, 500)
    }
  end
end
