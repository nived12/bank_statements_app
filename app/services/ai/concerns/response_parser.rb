# app/services/ai/concerns/response_parser.rb
require "json"
require "set"

module Ai
  module Concerns
    module ResponseParser
      def parse_ai_response(content, extraction_source)
        # Parse the AI response and return structured data
        begin
          json = JSON.parse(content.to_s)

          # Filter and resolve category names to IDs
          transactions = (json["transactions"] || []).select do |transaction|
            # Only include transactions with valid amounts and descriptions
            transaction["amount"].present? &&
            transaction["amount"] != "" &&
            transaction["amount"] != "0" &&
            transaction["amount"].to_f != 0.0 &&
            transaction["description"].present? &&
            transaction["description"].to_s.strip != "" &&
            transaction["description"].to_s.strip.length > 3 # Ensure meaningful description
          end.map do |transaction|
            resolve_category_ids(transaction)
          end

          # Remove duplicates based on date, amount, and description
          transactions = deduplicate_transactions(transactions)

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

      def deduplicate_transactions(transactions)
        # Remove duplicates based on date, amount, and description similarity
        unique_transactions = []
        seen_combinations = Set.new

        transactions.each do |transaction|
          # Create a key based on date, amount, and normalized description
          date = transaction["date"].to_s.strip
          amount = transaction["amount"].to_s.strip
          description = transaction["description"].to_s.strip.downcase.gsub(/\s+/, " ")

          # Create a combination key
          key = "#{date}|#{amount}|#{description}"

          # Only add if we haven't seen this combination before
          unless seen_combinations.include?(key)
            seen_combinations.add(key)
            unique_transactions << transaction
          end
        end

        unique_transactions
      end
    end
  end
end
