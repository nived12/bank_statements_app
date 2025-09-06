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

        # Normalize confidence
        t["confidence"] = t["confidence"].to_f.clamp(0.0, 1.0) if t.key?("confidence")
      end

      success(json)
    rescue => e
      errors.add(:base, "Failed to normalize transactions: #{e.message}")
      failure
    end
  end
end
