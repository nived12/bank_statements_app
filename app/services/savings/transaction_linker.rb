# frozen_string_literal: true

##
# Savings::TransactionLinker
# Manually links a transaction to a saving with a specific amount
#
class Savings::TransactionLinker < ApplicationService
  def initialize(saving, transaction, amount_applied, notes: nil, manual: true)
    super()
    @saving = saving
    @transaction = transaction
    @amount_applied = amount_applied
    @notes = notes
    @manual = manual
  end

  def call
    return failure("Saving must be active") unless saving.status_active?
    return failure("Amount applied cannot be zero") if amount_applied.zero?

    # Check if already linked
    existing_link = SavingTransaction.find_by(saving_id: saving.id, transaction_id: transaction.id)
    if existing_link
      return failure("Transaction is already linked to this saving")
    end

    # Create the link
    saving_transaction = SavingTransaction.create(
      saving: saving,
      transaction_id: transaction.id,
      amount_applied: amount_applied,
      notes: notes,
      manual: manual
    )

    success(saving_transaction)
  rescue ActiveRecord::RecordInvalid => e
    # Extract full error messages from the record
    error_messages = e.record.errors.full_messages.join(", ")
    failure(error_messages)
  rescue StandardError => e
    failure(e.message)
  end

  private

  attr_reader :saving, :transaction, :amount_applied, :notes, :manual
end
