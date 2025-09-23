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
          # Normalize the category name for matching
          normalized_category_name = transaction["category"].to_s.strip
          category = categories.find { |cat| cat.name.strip == normalized_category_name }
          if category
            transaction["category_id"] = category.id
            transaction.delete("category") # Remove the name, keep only ID
          else
            # Leave category_id as nil if category not found
            transaction["category_id"] = nil
            transaction.delete("category")
          end
        end

        # Resolve sub_category name to ID
        if transaction["sub_category"].present?
          # Normalize the sub_category name for matching
          normalized_sub_category_name = transaction["sub_category"].to_s.strip
          sub_category = categories.find { |cat| cat.name.strip == normalized_sub_category_name }
          if sub_category
            transaction["sub_category_id"] = sub_category.id
            transaction.delete("sub_category") # Remove the name, keep only ID
          else
            # Log the unmatched sub_category for debugging
            # Leave sub_category_id as nil if sub_category not found
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
