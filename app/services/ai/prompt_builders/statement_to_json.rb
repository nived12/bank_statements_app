require "yaml"

module Ai
  module PromptBuilders
    class StatementToJson
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
              "confidence": 0.0,
              "category_confidence": 0.0,
              "transaction_type_confidence": 0.0
            }
          ]
        }
      JSON

      def initialize(bank_name:, account_number:, categories:)
        @bank_name = bank_name
        @account_number = account_number
        @categories = categories
      end

      def build(raw_text:)
        taxonomy_json = taxonomy_payload(@categories).to_json
        fewshots_text = fewshots_block

        <<~PROMPT
          Convert the following bank statement text to STRICT JSON (no markdown).

          You must:
          - Dates: "YYYY-MM-DD".
          - Amount: decimal; negative for expenses, positive for incomes.
          - transaction_type: one of "income", "fixed_expense", "variable_expense".
            If unsure and amount < 0, default to "variable_expense".
          - bank_entry_type: "credit" or "debit" if determinable; else null.
          - Choose category and optional sub_category ONLY from the taxonomy below.
            If nothing fits, set category="Uncategorized" and sub_category=null.
          - Include "raw_text".
          - Include confidences 0..1: "confidence", "category_confidence", "transaction_type_confidence".
          - English keys and values only.
          - Return ONLY JSON shaped like:
          #{SCHEMA_HINT}

          Category taxonomy (choose only from here):
          #{taxonomy_json}

          Few-shot guidance (examples, NOT the data to parse):
          #{fewshots_text}

          Context:
          - bank_name: #{@bank_name}
          - account_number: #{@account_number}

          Text to convert:
          #{raw_text}
        PROMPT
      end

      private

      def taxonomy_payload(categories)
        parents = categories.where(parent_id: nil).includes(:children).order(:name)
        parents.map do |cat|
          { name: cat.name, subcategories: cat.children.order(:name).pluck(:name) }
        end.presence || [ { name: "Uncategorized", subcategories: [] } ]
      end

      def fewshots_block
        path = Rails.root.join("config/ai_fewshots/statement_examples.en.yml")
        return "" unless File.exist?(path)
        yaml = YAML.load_file(path)
        arr = yaml["examples"] || []
        arr.map do |ex|
          <<~EX
            Input: #{ex["text"]}
            Expected:
            #{ex["expected"].to_json}
          EX
        end.join("\n")
      rescue
        ""
      end
    end
  end
end
