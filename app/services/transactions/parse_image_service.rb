# frozen_string_literal: true

class Transactions::ParseImageService < ApplicationService
  VALID_TRANSACTION_TYPES = %w[income fixed_expense variable_expense transfer_in transfer_out].freeze
  EXTENSION_MAP = {
    "image/jpeg" => ".jpg",
    "image/png" => ".png",
    "image/webp" => ".webp"
  }.freeze

  def initialize(image_base64:, mime_type:, user:, vision_client: Ai::VisionClient.new)
    super()
    @image_base64 = image_base64
    @mime_type = mime_type
    @user = user
    @vision_client = vision_client
  end

  def call
    tempfile = write_tempfile
    categories = user_categories
    accounts = user_bank_accounts
    prompt = build_prompt(categories, accounts)

    raw = vision_client.analyze_document([tempfile.path], prompt)
    parsed = parse_json(raw[:text])
    return failure("AI returned unparseable response") if parsed.nil?

    success(build_result(parsed, categories, accounts))
  rescue StandardError => e
    Rails.logger.error("ParseImageService error: #{e.message}")
    failure("AI image parsing failed")
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  private

  attr_reader :image_base64, :mime_type, :user, :vision_client

  def write_tempfile
    ext = EXTENSION_MAP.fetch(mime_type, ".jpg")
    file = Tempfile.new(["receipt", ext])
    file.binmode
    file.write(Base64.decode64(image_base64))
    file.rewind
    file
  end

  def user_categories
    Category.where(user_id: [user.id, nil])
            .select(:id, :name)
            .map { |c| { id: c.id, name: c.name } }
  end

  def user_bank_accounts
    user.bank_accounts.includes(:bank).map do |a|
      { id: a.id, name: a.display_name, bank: a.bank&.name, type: a.account_type }
    end
  end

  def build_prompt(categories, accounts)
    <<~PROMPT
      You are a receipt parser for a personal finance app used by Mexican users.
      Analyze this receipt image and return ONLY a valid JSON object.

      CRITICAL: Keep "description" and "merchant_name" separate:
      • "description" = a SHORT human label (2–4 words) summarizing WHAT was bought.
        Examples: "Snacks y bebidas", "Café", "Despensa", "Gasolina", "Comida rápida".
        NEVER put the store name in description. If items are unclear, use the category name.
      • "merchant_name" = the STORE or BUSINESS name (e.g. "Oxxo", "Starbucks", "Walmart"), or null if not visible.

      JSON fields:
      - "amount": positive float (the total amount paid, no sign)
      - "description": short label of what was bought (NOT the store name)
      - "merchant_name": store or business name, or null
      - "transaction_type": one of "income", "fixed_expense", "variable_expense", "transfer_in", "transfer_out" — receipts are almost always "variable_expense"
      - "date": string in "YYYY-MM-DD" format if a date is visible on the receipt, or null if not found
      - "category_id": integer or null — the id of the best-matching category from: #{categories.to_json}
      - "bank_account_id": integer or null — the id of the matching bank account from: #{accounts.to_json} if the receipt shows a card/bank name. Return null if not determinable.
      - "items": array of objects with "name" (string) and "amount" (float) for each purchased item.
        Include only individual product lines — skip subtotals, taxes, totals, discounts, fees, and tips.
        Cap at 30 items. Return an empty array if no items are visible.
      - "tax_amount": positive float for total tax / IVA shown on the receipt footer, or null if not visible
      - "tip_amount": positive float for total tip / propina shown on the receipt footer, or null if not visible
      - "confidence": float between 0.0 and 1.0

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

    raw_items = Array(parsed["items"]).first(30)
    valid_items = raw_items.filter_map do |item|
      name = item["name"].to_s.strip
      item_amount = item["amount"].to_f.abs
      next if name.blank? || item_amount.zero?

      { name: name, amount: item_amount }
    end

    short_label = parsed["description"].to_s.strip
    concept_label = if merchant.present? && !short_label.start_with?(merchant)
      "#{merchant} - #{short_label}"
    else
      short_label
    end

    raw_tax = parsed["tax_amount"]
    tax_amount = raw_tax.present? ? raw_tax.to_f.abs : nil

    raw_tip = parsed["tip_amount"]
    tip_amount = raw_tip.present? ? raw_tip.to_f.abs : nil

    {
      amount: amount,
      description: concept_label,
      concept: concept_label,
      merchant: merchant,
      bank_account_id: bank_account_id,
      transaction_type: transaction_type,
      date: date,
      category_suggestion: category_suggestion,
      confidence: confidence,
      items: valid_items,
      tax_amount: tax_amount,
      tip_amount: tip_amount
    }
  end
end
