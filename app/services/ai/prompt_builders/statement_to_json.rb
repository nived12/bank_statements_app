require "yaml"

module Ai
  module PromptBuilders
    class StatementToJson
      SCHEMA_HINT = <<~JSON
        {
          "opening_balance": "string",
          "closing_balance": "string",
          "transactions": [
            {
              "date": "string",
              "description": "string",
              "amount": "string",
              "transaction_type": "string",
              "bank_entry_type": "string",
              "merchant": "string|null",
              "reference": "string|null",
              "category": "string",
              "sub_category": "string|null",
              "raw_text": "string",
              "confidence": "number",
              "category_confidence": "number",
              "transaction_type_confidence": "number"
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
          - Amount: decimal string (e.g., "1234.56", "-567.89"), NOT scientific notation or floats.
            Use exactly 2 decimal places for cents.
          - transaction_type: one of "income", "fixed_expense", "variable_expense".
            If unsure and amount < 0, default to "variable_expense".
          - bank_entry_type: "credit" or "debit" if determinable; else null.
          - merchant: Extract the business name, store name, or service provider from the transaction.
            If no clear merchant, extract the main transaction description.
          - reference: Extract transaction reference numbers, IDs, codes, or any alphanumeric identifiers.
            Look for patterns like "REF:", "ID:", "TXN:", or standalone codes.
          - IMPORTANT: Treat each transaction as separate even if they have the same concept/merchant.
            If you see multiple lines with the same concept but different amounts or reference numbers,
            create separate transaction entries for each one. Each unique combination of date, amount,
            and reference should be a separate transaction.
          - Choose category and optional sub_category ONLY from the taxonomy below.
            IMPORTANT: Use EXACT category names as shown in the taxonomy.
            Look for keywords in the transaction description to match categories:
            * Food/restaurant words → "Comida" category
            * Transport/gas/uber → "Transporte" category
            * Entertainment/movies/games → "Entretenimiento" category
            * Shopping/clothes/tech → "Compras" category
            * Health/medical → "Salud" category
            * Education/courses → "Educación" category
            * Utilities/services → "Servicios" category
            * Income/salary → "Ingresos" category
            If nothing fits, set category="Sin Categorizar" and sub_category=null.
          - Include "raw_text".
          - Include confidences 0..1: "confidence", "category_confidence", "transaction_type_confidence".
          - English keys and values only.
          - Return ONLY JSON shaped like:
          #{SCHEMA_HINT}

          Category taxonomy (choose only from here, use EXACT names):
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
        end.presence || [ { name: "Sin Categorizar", subcategories: [] } ]
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
