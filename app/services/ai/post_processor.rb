# app/services/ai/post_processor.rb
require "json"

module Ai
  class PostProcessor
    def initialize(client: Ai::Client.new)
      @client = client
    end

    def call(raw_text:, bank_name:, account_number:, categories:)
      prompt = Ai::PromptBuilders::StatementToJson
        .new(bank_name: bank_name, account_number: account_number, categories: categories)
        .build(raw_text: raw_text)

      content = @client.chat(prompt)

      # Validate that AI didn't return a template response
      if content.include?('"opening_balance": "string"') ||
         content.include?('"closing_balance": "string"')
        Rails.logger.warn("AI returned template response instead of actual data")
        return nil
      end

      json = JSON.parse(content)

      # Additional validation: ensure we have actual transaction data
      if json["transactions"]&.empty? && json["financial_summaries"]&.empty?
        Rails.logger.warn("AI returned empty transactions and financial summaries")
        return nil
      end

      normalize!(json)

      json
    rescue => e
      Rails.logger.error("Ai::PostProcessor error: #{e.message}")
      Rails.logger.error("AI: Raw text length: #{raw_text.length}")
      Rails.logger.error("AI: Categories count: #{categories.count}")
      nil
    end

    private

    def normalize!(json)
      json["transactions"] ||= []
      json["financial_summaries"] ||= []

      # Normalize balances to numbers
      json["opening_balance"] = normalize_balance(json["opening_balance"])
      json["closing_balance"] = normalize_balance(json["closing_balance"])

      json["transactions"].each do |t|
        # amount
        t["amount"] =
          case t["amount"]
          when String then t["amount"].to_s.tr(",", "").to_f
          else t["amount"].to_f
          end

        # transaction_type (fallback)
        unless %w[income fixed_expense variable_expense].include?(t["transaction_type"].to_s)
          t["transaction_type"] = t["amount"].to_f < 0 ? "variable_expense" : "income"
        end

        # bank_entry_type
        t["bank_entry_type"] =
          case t["bank_entry_type"].to_s.downcase.strip
          when "credit", "cr" then "credit"
          when "debit", "dr"  then "debit"
          else nil
          end

        # confidences
        %w[confidence category_confidence transaction_type_confidence].each do |k|
          t[k] = t[k].to_f.clamp(0.0, 1.0) if t.key?(k)
        end

        t["category"] ||= "Sin Categorizar"
      end

      # Normalize financial summaries
      json["financial_summaries"].each do |fs|
        # amount
        fs["amount"] =
          case fs["amount"]
          when String then fs["amount"].to_s.tr(",", "").to_f
          else fs["amount"].to_f
          end

        # Ensure type is one of the valid types
        valid_types = %w[balance fee interest commission installment total other]
        fs["type"] = valid_types.include?(fs["type"]&.downcase) ? fs["type"].downcase : "other"

        # Ensure description is present
        fs["description"] ||= "Financial Summary"
      end

      # Additional validation for Spanish banking terms
      validate_spanish_banking_terms!(json)

      # Additional validation for BBVA credit card statements
      validate_bbva_credit_card!(json)

      # Final validation to ensure transaction types match amounts
      validate_transaction_types!(json)
    end

    def validate_spanish_banking_terms!(json)
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
    end

    def validate_bbva_credit_card!(json)
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
    end

    def validate_transaction_types!(json)
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
    end

    def validate_transaction_type!(transaction)
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
    end

    def normalize_balance(balance)
      return nil if balance.nil?

      case balance
      when String
        # Remove commas and convert to float
        balance.to_s.tr(",", "").to_f
      when Numeric
        balance.to_f
      else
        balance.to_f
      end
    end
  end
end
