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
    prompt = build_prompt(categories)

    raw = Ai::Client.new.chat(prompt)
    parsed = parse_json(raw[:text])
    return failure("AI returned unparseable response") if parsed.nil?

    success(build_result(parsed, categories))
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

  def build_prompt(categories)
    <<~PROMPT
      You are a financial transaction parser for Mexican users.
      Parse the following text and return ONLY a valid JSON object with these exact fields:
      - "amount": positive float (absolute value, no sign)
      - "description": string (merchant name or short description, title-cased)
      - "transaction_type": one of "income", "fixed_expense", "variable_expense", "transfer_in", "transfer_out"
      - "date": string in "YYYY-MM-DD" format if a date is mentioned, or null if not
      - "category_id": integer or null — the id of the best-matching category from this list (use the id field, not the name): #{categories.to_json}
      - "confidence": float between 0.0 and 1.0

      Text: "#{text}"

      Return ONLY the JSON object. No markdown, no explanation, no code fences.
    PROMPT
  end

  def parse_json(raw_text)
    return nil if raw_text.blank?

    # Strip markdown code fences if present
    cleaned = raw_text.strip.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "").strip
    JSON.parse(cleaned)
  rescue JSON::ParserError
    nil
  end

  def build_result(parsed, categories)
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
    valid_ids = categories.map { |c| c[:id] }
    category_suggestion = if valid_ids.include?(category_id)
      cat = categories.find { |c| c[:id] == category_id }
      { id: cat[:id], name: cat[:name] }
    end

    {
      amount: amount,
      description: parsed["description"].to_s.strip,
      transaction_type: transaction_type,
      date: date,
      category_suggestion: category_suggestion,
      confidence: confidence
    }
  end
end
