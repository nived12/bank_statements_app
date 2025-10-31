# frozen_string_literal: true

##
# Debts::UnlinkTransactionService
# Removes the link between a transaction and a debt
#
class Debts::UnlinkTransactionService < ApplicationService
  def initialize(debt, transaction)
    super()
    @debt = debt
    @transaction = transaction
  end

  def call
    # Find the existing link
    debt_transaction = DebtTransaction.find_by(debt: debt, transaction_id: transaction.id)

    unless debt_transaction
      return failure("Transaction is not linked to this debt")
    end

    # Destroy the link (callbacks will update the debt's amount_paid and current_balance)
    debt_transaction.destroy!

    success(debt)
  rescue ActiveRecord::RecordInvalid => e
    # Extract full error messages from the record
    error_messages = e.record.errors.full_messages.join(", ")
    failure(error_messages)
  rescue StandardError => e
    failure(e.message)
  end

  private

  attr_reader :debt, :transaction
end
