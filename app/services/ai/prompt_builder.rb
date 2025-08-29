# app/services/ai/prompt_builder.rb
module Ai
  class PromptBuilder < ApplicationService
    def initialize
      super()
    end

    def build_categorization_prompt(raw_text, categories)
      unless raw_text.is_a?(String) && categories.respond_to?(:each)
        errors.add(:base, "raw_text must be a String and categories must respond to :each")
        return failure
      end

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
              "category": "category name",
              "sub_category": "subcategory name or null",
              "merchant": "merchant name or null",
              "transaction_type": "income", "variable_expense", or "fixed_expense",
              "confidence": 0.8,
              "category_confidence": 0.8
            },
            {
              "description": "second transaction description",
              "category": "category name",
              "sub_category": "subcategory name or null",
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
        6. Use the category names from the mapping above (e.g., "Ingresos", "Servicios")
        7. For subcategories, use the format "Category > Subcategory" from the mapping
      PROMPT

      success(prompt)
    rescue => e
      errors.add(:base, "Failed to build categorization prompt: #{e.message}")
      failure
    end

    private

    def build_category_taxonomy(categories)
      unless categories.respond_to?(:each)
        errors.add(:base, "categories must respond to :each")
        return failure
      end

      # Build a category name to ID mapping for the prompt
      # This allows AI to return category names, which we then convert to IDs efficiently
      category_mapping = {}

      categories.each do |category|
        unless category.respond_to?(:name) && category.respond_to?(:id) && category.respond_to?(:children)
          errors.add(:base, "Each category must respond to :name, :id, and :children")
          return failure
        end

        category_mapping[category.name] = category.id

        # Include subcategories if they exist
        category.children.each do |subcategory|
          unless subcategory.respond_to?(:name)
            errors.add(:base, "Each subcategory must respond to :name")
            return failure
          end
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
