require "json"

module Ai
  class PostProcessor
    SCHEMA_HINT = <<~JSON.freeze
      {
        "opening_balance": 0.0,
        "closing_balance": 0.0,
        "transactions": [
          {
            "date": "YYYY-MM-DD",
            "description": "string",
            "amount": 0.0,
            "type": "income or expense",
            "bank_entry_type": "credit or debit",
            "merchant": null,
            "reference": null,
            "category": "Uncategorized",
            "sub_category": null,
            "fixed_or_variable": "fijo or variable",
            "raw_text": "original line",
            "confidence": 0.0
          }
        ]
      }
    JSON

    def initialize(client: Ai::Client.new)
      @client = client
    end

    def build_prompt(raw_text:, bank_name:, account_number:)
      <<~PROMPT
        Transform the following raw text from a Mexican bank statement into STRICT JSON (no markdown, no prose).

        Output requirements:
        - Dates MUST be "YYYY-MM-DD".
        - "amount" is a decimal number; expenses negative (< 0), incomes positive (>= 0).
        - "type" MUST be:
          - "income" if amount >= 0
          - "expense" if amount < 0
        - "bank_entry_type" MUST reflect the statement entry when determinable: "credit" or "debit". If unknown, use null.
        - If unsure about category, use "Uncategorized".
        - "fixed_or_variable" MUST be "fijo" or "variable" (default "variable").
        - Include "raw_text" and a float "confidence" 0..1 for each transaction.
        - Return ONLY JSON that matches this schema example (values are illustrative):

        #{SCHEMA_HINT}

        Bank context (may help infer meaning):
        - bank_name: #{bank_name}
        - account_number: #{account_number}

        Now convert this raw text to JSON (return ONLY JSON):
        #{raw_text}
      PROMPT
    end

    def call(raw_text:, bank_name:, account_number:)
      content = @client.chat(
        build_prompt(raw_text: raw_text, bank_name: bank_name, account_number: account_number)
      )
      json = JSON.parse(content)

      normalize!(json)
      json
    rescue => e
      Rails.logger.error("Ai::PostProcessor error: #{e.message}")
      nil
    end

    private

    def normalize!(json)
      json["transactions"] ||= []
      json["transactions"].each do |t|
        # 1) Normalize amount to a numeric (AI should send a number, but be defensive)
        amt =
          case t["amount"]
          when String
            t["amount"].to_s.strip.tr(",", "").to_f
          else
            t["amount"].to_f
          end
        t["amount"] = amt

        # 2) If AI mistakenly put credit/debit in "type", move it to bank_entry_type
        raw_type = t["type"].to_s.downcase.strip
        if %w[credit debit].include?(raw_type)
          t["bank_entry_type"] = normalize_bank_entry_type(raw_type)
        end

        # 3) Canonical budgeting type by sign of amount
        t["type"] = amt < 0 ? "expense" : "income"

        # 4) Normalize bank_entry_type if present; otherwise keep/null
        if t.key?("bank_entry_type")
          t["bank_entry_type"] = normalize_bank_entry_type(t["bank_entry_type"])
        else
          t["bank_entry_type"] = nil
        end

        # 5) Defaults/safety
        t["fixed_or_variable"] = %w[fijo variable].include?(t["fixed_or_variable"]) ? t["fixed_or_variable"] : "variable"
        t["category"] ||= "Uncategorized"
        t["confidence"] = t["confidence"].to_f if t["confidence"]
      end
    end

    def normalize_bank_entry_type(val)
      v = val.to_s.downcase.strip
      return "credit" if v == "credit" || v == "cr"
      return "debit"  if v == "debit"  || v == "dr"
      nil
    end
  end
end
