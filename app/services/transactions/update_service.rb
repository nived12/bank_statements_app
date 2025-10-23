# frozen_string_literal: true

##
# Transactions::UpdateService
# Service for handling transaction updates
#
class Transactions::UpdateService < ApplicationService
  include Transactions::Concerns::SavingsDebtsLinkable

  def initialize(transaction_id, update_params)
    super()
    @transaction_id = transaction_id
    @update_params = update_params
  end

  def call
    find_transaction
    return failure unless transaction

    # Extract saving_ids and debt_ids before updating transaction
    saving_ids = update_params.delete(:saving_ids)
    debt_ids = update_params.delete(:debt_ids)

    update_transaction
    return failure if has_errors?

    # Handle manual savings and debts links
    update_savings_links(saving_ids)
    update_debts_links(debt_ids)

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

  def update_savings_links(new_saving_ids)
    # Get existing manual saving links
    existing_manual_links = transaction.saving_transactions.where(manual: true)
    existing_saving_ids = existing_manual_links.pluck(:saving_id)

    # Convert new_saving_ids to array of integers (empty/nil means uncheck all)
    new_saving_ids = Array(new_saving_ids).reject(&:blank?).map(&:to_i)

    # Determine which savings to remove and which to add
    saving_ids_to_remove = existing_saving_ids - new_saving_ids
    saving_ids_to_add = new_saving_ids - existing_saving_ids
    saving_ids_to_update = existing_saving_ids & new_saving_ids

    # Remove manual links that are no longer selected
    if saving_ids_to_remove.any?
      existing_manual_links.where(saving_id: saving_ids_to_remove).each do |saving_transaction|
        # Use the service to properly handle saving amount updates
        Savings::UnlinkTransactionService.call(saving_transaction.saving, transaction)
      end
    end

    # Update existing links (recalculate amount_applied in case transaction amount changed)
    if saving_ids_to_update.any?
      existing_manual_links.where(saving_id: saving_ids_to_update).each do |saving_transaction|
        saving = saving_transaction.saving
        new_amount = saving.calculate_amount_for_transaction(transaction)

        if new_amount.nil?
          # If the transaction type is now set to 'ignore', remove the link
          Savings::UnlinkTransactionService.call(saving, transaction)
        elsif saving_transaction.amount_applied != new_amount
          # Update the amount - the SavingTransaction callback will handle updating saving's current_amount
          saving_transaction.update!(amount_applied: new_amount)
        end
      end
    end

    # Add new manual links
    if saving_ids_to_add.any?
      link_to_savings(transaction, saving_ids_to_add)
    end
  end

  def update_debts_links(new_debt_ids)
    # Get existing manual debt links
    existing_manual_links = transaction.debt_transactions.where(manual: true)
    existing_debt_ids = existing_manual_links.pluck(:debt_id)

    # Convert new_debt_ids to array of integers (empty/nil means uncheck all)
    new_debt_ids = Array(new_debt_ids).reject(&:blank?).map(&:to_i)

    # Determine which debts to remove and which to add
    debt_ids_to_remove = existing_debt_ids - new_debt_ids
    debt_ids_to_add = new_debt_ids - existing_debt_ids
    debt_ids_to_update = existing_debt_ids & new_debt_ids

    # Remove manual links that are no longer selected
    if debt_ids_to_remove.any?
      existing_manual_links.where(debt_id: debt_ids_to_remove).each do |debt_transaction|
        # Use the service to properly handle debt amount updates
        Debts::UnlinkTransactionService.call(debt_transaction.debt, transaction)
      end
    end

    # Update existing links (recalculate amount_applied in case transaction amount changed)
    if debt_ids_to_update.any?
      existing_manual_links.where(debt_id: debt_ids_to_update).each do |debt_transaction|
        debt = debt_transaction.debt
        new_amount = debt.calculate_amount_for_transaction(transaction)

        if new_amount.nil?
          # If the transaction type is now set to 'ignore', remove the link
          Debts::UnlinkTransactionService.call(debt, transaction)
        elsif debt_transaction.amount_applied != new_amount
          # Update the amount - the DebtTransaction callback will handle updating debt's current_amount
          debt_transaction.update!(amount_applied: new_amount)
        end
      end
    end

    # Add new manual links
    if debt_ids_to_add.any?
      link_to_debts(transaction, debt_ids_to_add)
    end
  end
end
