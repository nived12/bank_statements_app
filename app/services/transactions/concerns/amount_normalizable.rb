# frozen_string_literal: true

module Transactions
  module Concerns
    module AmountNormalizable
      private

      def normalize_amount_sign(params_hash, transaction = nil)
        return unless params_hash[:amount].present?

        amount = params_hash[:amount].to_d.abs.round(2)

        # For transfers, always use transaction's type (params transaction_type is ignored for transfers)
        transaction_type = if transaction&.transfer?
          transaction.transaction_type
        else
          params_hash[:transaction_type] || transaction&.transaction_type
        end
        return if transaction_type.nil?

        params_hash[:amount] = calculate_signed_amount(transaction_type, amount)
      end

      def calculate_signed_amount(transaction_type, amount)
        return -amount if %w[fixed_expense variable_expense transfer_out].include?(transaction_type)

        amount
      end
    end
  end
end
