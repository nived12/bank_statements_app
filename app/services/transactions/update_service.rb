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

      # If this is a transfer, sync changes to linked transfer
      sync_to_linked_transfer(filtered_params)
    end
  rescue => e
    errors.add(:base, e.message)
  end

  def sync_to_linked_transfer(params)
    # Only sync if this is a transfer and has a linked transfer
    return unless transaction.transfer?
    return unless transaction.linked_transfer

    # Prepare attributes to sync (all editable fields except amount)
    sync_params = {}

    # Sync these fields directly if they were updated
    [:date, :description, :category_id, :merchant, :reference].each do |field|
      sync_params[field] = params[field] if params.key?(field)
    end

    # Sync amount with opposite sign
    if params.key?(:amount)
      sync_params[:amount] = -params[:amount].to_f
    end

    # Update the linked transfer if there are any changes to sync
    return if sync_params.empty?

    unless transaction.linked_transfer.update(sync_params)
      errors.add(:base, "Failed to sync changes to linked transfer")
      raise ActiveRecord::Rollback
    end
  end
end
