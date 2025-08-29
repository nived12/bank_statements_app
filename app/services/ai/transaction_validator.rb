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

    def validate_spanish_banking_terms!(json)
      unless json.is_a?(Hash) && json["transactions"]
        errors.add(:base, "Input must be a Hash with transactions")
        return failure
      end

      # Look for Spanish banking terms in raw_text to detect potential misinterpretations
      json["transactions"].each do |t|
        raw_text = t["raw_text"]&.downcase || ""

        # If raw text contains Spanish banking terms, validate the interpretation
        if raw_text.include?("importe cargos") || raw_text.include?("cargos")
          # CARGOS should be negative (expenses)
          if t["amount"].to_f > 0
            Rails.logger.warn("Spanish banking term validation: CARGOS amount should be negative, correcting #{t['amount']} to #{-t['amount'].abs}")
            t["amount"] = -t["amount"].abs
            t["transaction_type"] = "variable_expense"
            t["bank_entry_type"] = "debit"
          end
        elsif raw_text.include?("importe abonos") || raw_text.include?("abonos")
          # ABONOS should be positive (income)
          if t["amount"].to_f < 0
            Rails.logger.warn("Spanish banking term validation: ABONOS amount should be positive, correcting #{t['amount']} to #{t['amount'].abs}")
            t["amount"] = t["amount"].abs
            t["transaction_type"] = "income"
            t["bank_entry_type"] = "credit"
          end
        end
      end

      success(json)
    rescue => e
      errors.add(:base, "Failed to validate Spanish banking terms: #{e.message}")
      failure
    end

    def validate_bbva_credit_card!(json)
      unless json.is_a?(Hash) && json["transactions"]
        errors.add(:base, "Input must be a Hash with transactions")
        return failure
      end

      # Additional validation specific to BBVA credit card statements
      json["transactions"].each do |t|
        raw_text = t["raw_text"]&.downcase || ""

        # Check for BBVA credit card specific patterns
        if raw_text.include?("anualidad") || raw_text.include?("fee")
          # Annual fees should be negative expenses
          if t["amount"].to_f > 0
            Rails.logger.warn("BBVA credit card validation: Annual fee should be negative, correcting #{t['amount']} to #{-t['amount'].abs}")
            t["amount"] = -t["amount"].abs
            t["transaction_type"] = "variable_expense"
            t["bank_entry_type"] = "debit"
          end
        elsif raw_text.include?("pago tdc") || raw_text.include?("payment")
          # Credit card payments should be positive income
          if t["amount"].to_f < 0
            Rails.logger.warn("BBVA credit card validation: Payment should be positive, correcting #{t['amount']} to #{t['amount'].abs}")
            t["amount"] = t["amount"].abs
            t["transaction_type"] = "income"
            t["bank_entry_type"] = "credit"
          end
        end

        # Validate transaction types based on amount and context
        validate_transaction_type!(t)
      end

      success(json)
    rescue => e
      errors.add(:base, "Failed to validate BBVA credit card: #{e.message}")
      failure
    end

    def validate_transaction_types!(json)
      unless json.is_a?(Hash) && json["transactions"]
        errors.add(:base, "Input must be a Hash with transactions")
        return failure
      end

      # Final validation to ensure all transaction types are consistent with amounts
      json["transactions"].each do |t|
        amount = t["amount"].to_f
        current_type = t["transaction_type"]
        current_bank_type = t["bank_entry_type"]

        # Ensure transaction type matches amount sign
        if amount < 0 && current_type != "variable_expense"
          Rails.logger.warn("Transaction type validation: Negative amount should be variable_expense, correcting #{current_type}")
          t["transaction_type"] = "variable_expense"
          t["bank_entry_type"] = "debit"
        elsif amount > 0 && current_type != "income"
          Rails.logger.warn("Transaction type validation: Positive amount should be income, correcting #{current_type}")
          t["transaction_type"] = "income"
          t["bank_entry_type"] = "credit"
        end

        # Ensure bank entry type is consistent
        if amount < 0 && current_bank_type != "debit"
          t["bank_entry_type"] = "debit"
        elsif amount > 0 && current_bank_type != "credit"
          t["bank_entry_type"] = "credit"
        end
      end

      success(json)
    rescue => e
      errors.add(:base, "Failed to validate transaction types: #{e.message}")
      failure
    end

    def validate_transaction_type!(transaction)
      unless transaction.is_a?(Hash)
        errors.add(:base, "Input must be a Hash")
        return failure
      end

      amount = transaction["amount"].to_f
      current_type = transaction["transaction_type"]

      # Ensure transaction type matches amount sign
      if amount < 0 && current_type != "variable_expense"
        Rails.logger.warn("Transaction type validation: Negative amount should be variable_expense, correcting #{current_type}")
        transaction["transaction_type"] = "variable_expense"
        transaction["bank_entry_type"] = "debit"
      elsif amount > 0 && current_type != "income"
        Rails.logger.warn("Transaction type validation: Positive amount should be income, correcting #{current_type}")
        transaction["transaction_type"] = "income"
        transaction["bank_entry_type"] = "credit"
      end

      success(transaction)
    rescue => e
      errors.add(:base, "Failed to validate transaction: #{e.message}")
      failure
    end

    def normalize_balance(balance)
      return success(nil) if balance.nil?

      case balance
      when String
        # Remove commas and convert to float
        result = balance.to_s.tr(",", "").to_f
        success(result)
      when Numeric
        result = balance.to_f
        success(result)
      else
        result = balance.to_f
        success(result)
      end
    rescue => e
      errors.add(:base, "Failed to normalize balance: #{e.message}")
      failure
    end
  end
end
