# frozen_string_literal: true

##
# Savings::UnlinkTransactionService
# Removes the link between a transaction and a saving
#
class Savings::UnlinkTransactionService < ApplicationService
  def initialize(saving, transaction)
    super()
    @saving = saving
    @transaction = transaction
  end

  def call
    # Find the existing link
    saving_transaction = SavingTransaction.find_by(saving: saving, transaction_id: transaction.id)

    unless saving_transaction
      return failure("Transaction is not linked to this saving")
    end

    # Destroy the link (callbacks will update the saving's current_amount)
    saving_transaction.destroy!

    success(saving)
  rescue ActiveRecord::RecordInvalid => e
    # Extract full error messages from the record
    error_messages = e.record.errors.full_messages.join(", ")
    failure(error_messages)
  rescue StandardError => e
    failure(e.message)
  end

  private

  attr_reader :saving, :transaction
end
