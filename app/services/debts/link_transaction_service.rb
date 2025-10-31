# frozen_string_literal: true

##
# Debts::LinkTransactionService
# Manually links a transaction to a debt with a specific amount
#
class Debts::LinkTransactionService < ApplicationService
  def initialize(debt, transaction, amount_applied, notes: nil, manual: true)
    super()
    @debt = debt
    @transaction = transaction
    @amount_applied = amount_applied
    @notes = notes
    @manual = manual
  end

  def call
    return failure("Debt must be active") unless debt.status_active?
    return failure("Amount applied cannot be zero") if amount_applied.zero?

    # Check if already linked
    existing_link = DebtTransaction.find_by(debt: debt, transaction_id: transaction.id)
    if existing_link
      return failure("Transaction is already linked to this debt")
    end

    # Create the link
    debt_transaction = DebtTransaction.create!(
      debt: debt,
      transaction_id: transaction.id,
      amount_applied: amount_applied,
      notes: notes,
      manual: manual
    )

    success(debt_transaction)
  rescue ActiveRecord::RecordInvalid => e
    # Extract full error messages from the record
    error_messages = e.record.errors.full_messages.join(", ")
    failure(error_messages)
  rescue StandardError => e
    failure(e.message)
  end

  private

  attr_reader :debt, :transaction, :amount_applied, :notes, :manual
end
