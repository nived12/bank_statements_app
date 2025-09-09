# frozen_string_literal: true

##
# Transactions::UpdateService
# Service for handling transaction updates
#
class Transactions::UpdateService < ApplicationService
  def initialize(transaction_id, update_params)
    super()
    @transaction_id = transaction_id
    @update_params = update_params
  end

  def call
    find_transaction
    return failure unless transaction

    update_transaction
    return failure if has_errors?

    success(transaction)
  end

  private

  attr_reader :transaction_id, :update_params, :transaction

  def find_transaction
    @transaction = Current.user.transactions.find_by(id: transaction_id)
    return if transaction

    errors.add(:base, "Transaction not found")
  end

  def update_transaction
    unless transaction.update(update_params)
      transaction.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  rescue => e
    errors.add(:base, e.message)
  end
end
