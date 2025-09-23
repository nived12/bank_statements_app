# app/services/ai/transaction_validator.rb
module Ai
  class TransactionValidator < ApplicationService
    def initialize
      super()
    end

    def normalize!(json)
      unless json.is_a?(Hash)
        errors.add(:base, "Input must be a Hash")
        return failure
      end

      json["transactions"] ||= []

      json["transactions"].each do |t|
        # Ensure required fields are present
        t["category"] ||= "Sin Categorizar"
        t["transaction_type"] ||= "variable_expense"

        # Normalize confidence fields
        t["confidence"] = normalize_confidence(t["confidence"])
        t["category_confidence"] = normalize_confidence(t["category_confidence"])
        t["transaction_type_confidence"] = normalize_confidence(t["transaction_type_confidence"])
      end

      success(json)
    rescue => e
      errors.add(:base, "Failed to normalize transactions: #{e.message}")
      failure
    end

    private

    def normalize_confidence(value)
      return nil if value.nil?

      value.to_f.clamp(0.0, 1.0)
    end
  end
end
