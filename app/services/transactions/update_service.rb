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
    # Remove transfer_account_id as it's only used during creation
    filtered_params = update_params.except(:transfer_account_id)

    # For transfers, preserve transaction_type and bank_account_id
    # These should never change as they define the transfer relationship
    if transaction.transfer?
      filtered_params = filtered_params.except(:transaction_type, :bank_account_id)
    end

    ActiveRecord::Base.transaction do
      unless transaction.update(filtered_params)
        transaction.errors.each do |error|
          errors.add(error.attribute, error.message)
        end
        raise ActiveRecord::Rollback
      end

      # If this is a transfer and category was updated, sync to linked transfer
      sync_category_to_linked_transfer(filtered_params)
    end
  rescue => e
    errors.add(:base, e.message)
  end

  def sync_category_to_linked_transfer(params)
    # Only sync if this is a transfer and category_id was provided in params
    return unless transaction.transfer?
    return unless params.key?(:category_id)
    return unless transaction.linked_transfer

    # Update the linked transfer's category to match
    unless transaction.linked_transfer.update(category_id: params[:category_id])
      errors.add(:base, "Failed to sync category to linked transfer")
      raise ActiveRecord::Rollback
    end
  end
end
