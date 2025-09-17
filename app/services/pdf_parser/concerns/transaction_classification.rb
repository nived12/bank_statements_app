# app/services/pdf_parser/concerns/transaction_classification.rb
module PdfParser
  module Concerns
    module TransactionClassification
      extend ActiveSupport::Concern

      private

      def classify_transaction(transaction, amount_value)
        description = transaction["description"].to_s.upcase

        if is_deposit?(description)
          # This is a deposit (positive)
          transaction["amount"] = amount_value.to_s
          transaction["transaction_type"] = "income"
          transaction["bank_entry_type"] = "credit"
        elsif is_withdrawal?(description)
          # This is a withdrawal (negative)
          transaction["amount"] = (-amount_value).to_s
          transaction["transaction_type"] = "variable_expense"
          transaction["bank_entry_type"] = "debit"
        else
          # Default: use amount sign
          if amount_value > 0
            transaction["amount"] = amount_value.to_s
            transaction["transaction_type"] = "income"
            transaction["bank_entry_type"] = "credit"
          else
            transaction["amount"] = amount_value.to_s
            transaction["transaction_type"] = "variable_expense"
            transaction["bank_entry_type"] = "debit"
          end
        end

        transaction
      end

      def is_deposit?(description)
        # Check for withdrawal patterns first - if found, it's not a deposit
        return false if is_withdrawal?(description)

        description.include?("ABONO") ||
        description.include?("DEPOSITO") ||
        (description.include?("TRANSFERENCIA") && description.include?("RECIBIDO"))
      end

      def is_withdrawal?(description)
        description.include?("RETIRO") ||
        description.include?("CARGO") ||
        description.include?("PAGO") ||
        description.include?("AHORRO MIS METAS") ||
        (description.include?("TRANSFERENCIA") && !description.include?("RECIBIDO"))
      end

      def match_transaction_with_amounts(transaction, pending_amounts)
        # Use the first pending amount for this transaction
        return transaction unless pending_amounts.any?

        amounts = pending_amounts.first

        if amounts.length >= 2
          # First amount is transaction amount, second is balance
          transaction_amount = amounts[0]
          amount_value = parse_decimal(transaction_amount)
          classify_transaction(transaction, amount_value)
        elsif amounts.length == 1
          # Single amount
          amount = parse_decimal(amounts[0])
          classify_transaction(transaction, amount)
        end

        transaction
      end
    end
  end
end
