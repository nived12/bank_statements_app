# app/services/ai/concerns/response_parser.rb
require "json"

module Ai
  module Concerns
    module ResponseParser
      def parse_ai_response(content, extraction_source)
        # Parse the AI response and return structured data
        begin
          json = JSON.parse(content.to_s)

          # Filter and resolve category names to IDs
          transactions = (json["transactions"] || []).select do |transaction|
            # Only include transactions with valid amounts
            transaction["amount"].present? &&
            transaction["amount"] != "" &&
            transaction["amount"] != "0" &&
            transaction["amount"].to_f != 0.0
          end.map do |transaction|
            resolve_category_ids(transaction)
          end

          result = {
            "transactions" => transactions,
            "extraction_source" => extraction_source
          }
          success(result)
        rescue JSON::ParserError => e
          errors.add(:base, "Failed to parse AI response as JSON: #{e.message}")
          failure
        end
      end

      private

      def resolve_category_ids(transaction)
        # Resolve category name to ID
        if transaction["category"].present?
          category = categories.find { |cat| cat.name == transaction["category"] }
          if category
            transaction["category_id"] = category.id
            transaction.delete("category") # Remove the name, keep only ID
          else
            # Fallback to "Sin Categorizar" if category not found
            uncategorized = categories.find { |cat| cat.name == "Sin Categorizar" }
            transaction["category_id"] = uncategorized&.id
            transaction.delete("category")
          end
        end

        # Resolve sub_category name to ID
        if transaction["sub_category"].present?
          sub_category = categories.find { |cat| cat.name == transaction["sub_category"] }
          if sub_category
            transaction["sub_category_id"] = sub_category.id
            transaction.delete("sub_category") # Remove the name, keep only ID
          else
            transaction["sub_category_id"] = nil
            transaction.delete("sub_category")
          end
        end

        transaction
      end
    end
  end
end
