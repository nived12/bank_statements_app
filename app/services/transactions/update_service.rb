# frozen_string_literal: true

##
# Transactions::UpdateService
# Service for handling transaction updates
#
class Transactions::UpdateService < ApplicationService
  include Transactions::Concerns::GoalLinkable

  def initialize(transaction_id, update_params)
    super()
    @transaction_id = transaction_id
    @update_params = update_params
  end

  def call
    find_transaction
    return failure unless transaction

    # Extract goal_ids before updating transaction
    goal_ids = update_params.delete(:goal_ids)

    update_transaction
    return failure if has_errors?

    # Handle manual goal links
    update_goal_links(goal_ids)

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

  def update_goal_links(new_goal_ids)
    # Get existing manual goal links
    existing_manual_links = transaction.goal_transactions.where(manual: true)
    existing_goal_ids = existing_manual_links.pluck(:goal_id)

    # Convert new_goal_ids to array of integers (empty/nil means uncheck all)
    new_goal_ids = Array(new_goal_ids).reject(&:blank?).map(&:to_i)

    # Determine which goals to remove and which to add
    goal_ids_to_remove = existing_goal_ids - new_goal_ids
    goal_ids_to_add = new_goal_ids - existing_goal_ids
    goal_ids_to_update = existing_goal_ids & new_goal_ids

    # Remove manual links that are no longer selected
    if goal_ids_to_remove.any?
      existing_manual_links.where(goal_id: goal_ids_to_remove).each do |goal_transaction|
        # Use the service to properly handle goal amount updates
        Goals::UnlinkTransactionService.call(goal_transaction.goal, transaction)
      end
    end

    # Update existing links (recalculate amount_applied in case transaction amount changed)
    if goal_ids_to_update.any?
      existing_manual_links.where(goal_id: goal_ids_to_update).each do |goal_transaction|
        goal = goal_transaction.goal
        new_amount = goal.calculate_amount_for_transaction(transaction)

        if new_amount.nil?
          # If the transaction type is now set to 'ignore', remove the link
          Goals::UnlinkTransactionService.call(goal, transaction)
        elsif goal_transaction.amount_applied != new_amount
          # Update the amount - the GoalTransaction callback will handle updating goal's current_amount
          goal_transaction.update!(amount_applied: new_amount)
        end
      end
    end

    # Add new manual links
    if goal_ids_to_add.any?
      link_to_goals(transaction, goal_ids_to_add)
    end
  end
end
