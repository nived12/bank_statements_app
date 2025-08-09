# app/services/ai/post_processor.rb
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
            "transaction_type": "income | fixed_expense | variable_expense",
            "bank_entry_type": "credit | debit | null",
            "merchant": null,
            "reference": null,
            "category": "Uncategorized",
            "sub_category": null,
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
        Convert the following bank statement text to STRICT JSON (no markdown, no prose).

        Rules:
        - Dates: "YYYY-MM-DD".
        - Amount: decimal; negative for expenses, positive for incomes.
        - transaction_type: "income", "fixed_expense", or "variable_expense".
          If unsure and amount < 0, default to "variable_expense".
        - bank_entry_type: "credit" or "debit" if determinable; else null.
        - English keys and values only.
        - Include "raw_text" and numeric "confidence" 0..1.
        - Return ONLY JSON shaped like:
        #{SCHEMA_HINT}

        Context:
        - bank_name: #{bank_name}
        - account_number: #{account_number}

        Text:
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
        amt = t["amount"].is_a?(String) ? t["amount"].tr(",", "").to_f : t["amount"].to_f
        t["amount"] = amt

        # Finalize transaction_type if missing
        unless %w[income fixed_expense variable_expense].include?(t["transaction_type"].to_s)
          t["transaction_type"] = amt < 0 ? "variable_expense" : "income"
        end

        # bank_entry_type cleanup
        t["bank_entry_type"] =
          case t["bank_entry_type"].to_s.downcase.strip
          when "credit", "cr" then "credit"
          when "debit", "dr"  then "debit"
          else nil
          end

        # Remove any legacy keys if the model invented them
        t.delete("type")
        t.delete("fixed_or_variable")

        t["category"] ||= "Uncategorized"
        t["confidence"] = t["confidence"].to_f if t["confidence"]
      end
    end
  end
end
