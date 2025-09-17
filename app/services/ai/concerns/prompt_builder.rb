# app/services/ai/concerns/prompt_builder.rb
module Ai
  module Concerns
    module PromptBuilder
      def build_categorization_prompt(raw_text, categories)
        # Build a simple, cost-effective prompt for categorization only
        taxonomy_result = build_category_taxonomy(categories)
        return failure unless taxonomy_result.success?

        taxonomy = taxonomy_result.payload

        prompt = <<~PROMPT
          You are a transaction categorizer. Process the following transaction descriptions and return them in JSON format.

          **INPUT FORMAT: Each line below represents a separate transaction.**

          **RULES:**
          - SPEI ENVIADO, RETIRO, PAGO → "Servicios" + "variable_expense"
          - DEPOSITO, NOMINA, BONO, RECIBIDO → "Ingresos" + "income"
          - SPEI RECIBIDO → "Ingresos" + "income"
          - PAGO INTERBANCARIO, PAGO CUENTA, PAGO TARJETA → "Servicios" + "variable_expense"
          - RETIRO SIN TARJETA → "Servicios" + "variable_expense"
          - DEPOSITO DE TERCERO → "Ingresos" + "income"
          - NETFLIX, SPOTIFY, CFE, TELMEX, GAS → "Servicios" + "fixed_expense"

          **REQUIRED FORMAT:**
          {
            "transactions": [
              {
                "description": "transaction description",
                "category_id": 123,
                "sub_category_id": 456,
                "merchant": "merchant name or null",
                "transaction_type": "income", "variable_expense", or "fixed_expense",
                "confidence": 0.8,
                "category_confidence": 0.8
              },
              {
                "description": "second transaction description",
                "category_id": 789,
                "sub_category_id": null,
                "merchant": "merchant name or null",
                "transaction_type": "income", "variable_expense", or "fixed_expense",
                "confidence": 0.8,
                "category_confidence": 0.8
              }
            ]
          }

          **CATEGORIES (Name → ID mapping):**
          #{taxonomy}

          **TRANSACTIONS TO CATEGORIZE (one per line):**
          #{raw_text}

          **CRITICAL INSTRUCTIONS:**
          1. Count the number of lines above
          2. Create exactly that many transactions in the response
          3. Each line = one transaction
          4. Do not skip any lines
          5. Return ALL transactions
          6. Use the category IDs from the mapping above (e.g., 123, 456, 789)
          7. For subcategories, use the subcategory ID from the mapping
          8. Use null for sub_category_id if no subcategory applies
        PROMPT

        success(prompt)
      rescue => e
        errors.add(:base, "Failed to build categorization prompt: #{e.message}")
        failure
      end

      private

      def build_category_taxonomy(categories)
        # Build a category name to ID mapping for the prompt
        # This allows AI to return category names, which we then convert to IDs efficiently
        category_mapping = {}

        categories.each do |category|
          category_mapping[category.name] = category.id

          # Include subcategories if they exist
          category.children.each do |subcategory|
            category_mapping["#{category.name} > #{subcategory.name}"] = subcategory.id
          end
        end

        # Return as JSON for the AI to use
        result = category_mapping.to_json
        success(result)
      rescue => e
        errors.add(:base, "Failed to build category taxonomy: #{e.message}")
        failure
      end
    end
  end
end
