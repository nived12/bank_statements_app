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

    # Extract goal_id before updating transaction
    goal_id = update_params.delete(:goal_id)

    update_transaction
    return failure if has_errors?

    # Manually link to goal if specified
    if goal_id.present?
      link_to_goal(goal_id)
    end

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

  def link_to_goal(goal_id)
    goal = Current.user.goals.find_by(id: goal_id)

    unless goal
      errors.add(:goal, "not found")
      return
    end

    # Skip if goal is not active
    unless goal.status_active?
      errors.add(:goal, "must be active to link transactions")
      return
    end

    # Check if already manually linked to this goal
    existing_link = transaction.goal_transactions.find_by(goal_id: goal.id, manual: true)
    return if existing_link.present?

    # Calculate amount based on goal's settings
    amount_to_apply = goal.calculate_amount_for_transaction(transaction)

    # If amount is nil (ignore setting), skip linking
    # But log a warning since user explicitly requested it
    if amount_to_apply.nil?
      Rails.logger.warn(
        "Transaction #{transaction.id} not linked to goal #{goal.id}: " \
        "transaction type #{transaction.transaction_type} is set to 'ignore' in goal settings"
      )
      return
    end

    # Link the transaction
    result = Goals::LinkTransactionService.call(
      goal,
      transaction,
      amount_to_apply,
      notes: "Manually linked",
      manual: true
    )

    unless result.success?
      result.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
    end
  end
end
