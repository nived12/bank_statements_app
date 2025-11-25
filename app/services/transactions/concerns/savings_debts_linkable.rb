# frozen_string_literal: true

##
# Transactions::Concerns::SavingsDebtsLinkable
# Shared concern for manual savings and debts linking in transaction services
#
module Transactions::Concerns::SavingsDebtsLinkable
  extend ActiveSupport::Concern

  private

  # Manually link a transaction to multiple savings
  # This method doesn't fail the transaction creation/update if savings linking fails
  def link_to_savings(transaction, saving_ids)
    saving_ids = Array(saving_ids).compact_blank
    return if saving_ids.empty?

    saving_ids.each do |saving_id|
      link_to_saving(transaction, saving_id)
    end
  end

  # Manually link a transaction to multiple debts
  # This method doesn't fail the transaction creation/update if debts linking fails
  def link_to_debts(transaction, debt_ids)
    return if debt_ids.blank?

    # Ensure debt_ids is an array
    debt_ids = Array(debt_ids).compact_blank
    return if debt_ids.empty?

    debt_ids.each do |debt_id|
      link_to_debt(transaction, debt_id)
    end
  end

  # Manually link a transaction to a single saving
  # This method doesn't fail the transaction creation/update if saving linking fails
  def link_to_saving(transaction, saving_id)
    saving = Current.user.savings.find_by(id: saving_id)

    unless saving
      # Log but don't fail the transaction creation/update
      Rails.logger.warn("Transaction #{transaction.id} not linked: saving #{saving_id} not found")
      return
    end

    # Skip if saving is not active
    unless saving.status_active?
      # Log but don't fail the transaction creation/update
      Rails.logger.warn("Transaction #{transaction.id} not linked: saving #{saving.id} is not active")
      return
    end

    # Check if already linked to this saving (manual OR auto) to avoid duplicates
    existing_link = transaction.saving_transactions.find_by(saving_id: saving.id)
    if existing_link.present?
      # If an auto-link exists, update it to manual since user explicitly selected it
      if !existing_link.manual?
        existing_link.update_columns(manual: true, notes: "Manually linked")
      end
      return
    end

    # Calculate amount based on saving's settings
    amount_to_apply = saving.calculate_amount_for_transaction(transaction)

    # If amount is nil (ignore setting), skip linking
    # But log a warning since user explicitly requested it
    if amount_to_apply.nil?
      Rails.logger.warn(
        "Transaction #{transaction.id} not linked to saving #{saving.id}: " \
        "transaction type #{transaction.transaction_type} is set to 'ignore' in saving settings"
      )
      return
    end

    # Link the transaction
    result = Savings::LinkTransactionService.call(
      saving,
      transaction,
      amount_to_apply,
      notes: "Manually linked",
      manual: true
    )

    # Log linking errors but don't fail the transaction creation/update
    Rails.logger.error(
      "Failed to link transaction #{transaction.id} to saving #{saving.id}: " \
      "#{result.errors.full_messages.join(", ")}"
    ) if result.failure?
  end

  # Manually link a transaction to a single debt
  # This method doesn't fail the transaction creation/update if debt linking fails
  def link_to_debt(transaction, debt_id)
    debt = Current.user.debts.find_by(id: debt_id)

    unless debt
      # Log but don't fail the transaction creation/update
      Rails.logger.warn("Transaction #{transaction.id} not linked: debt #{debt_id} not found")
      return
    end

    # Skip if debt is not active
    unless debt.status_active?
      # Log but don't fail the transaction creation/update
      Rails.logger.warn("Transaction #{transaction.id} not linked: debt #{debt.id} is not active")
      return
    end

    # Check if already linked to this debt (manual OR auto) to avoid duplicates
    existing_link = transaction.debt_transactions.find_by(debt_id: debt.id)
    if existing_link.present?
      # If an auto-link exists, update it to manual since user explicitly selected it
      if !existing_link.manual?
        existing_link.update(manual: true, notes: "Manually linked")
      end
      return
    end

    # Calculate amount based on debt's settings
    amount_to_apply = debt.calculate_amount_for_transaction(transaction)

    # If amount is nil (ignore setting), skip linking
    # But log a warning since user explicitly requested it
    if amount_to_apply.nil?
      Rails.logger.warn(
        "Transaction #{transaction.id} not linked to debt #{debt.id}: " \
        "transaction type #{transaction.transaction_type} is set to 'ignore' in debt settings"
      )
      return
    end

    # Link the transaction
    result = Debts::LinkTransactionService.call(
      debt,
      transaction,
      amount_to_apply,
      notes: "Manually linked",
      manual: true
    )

    Rails.logger.error(
      "Failed to link transaction #{transaction.id} to debt #{debt.id}: " \
      "#{result.errors.full_messages.join(", ")}"
    ) unless result.success?
  end

  # Update savings links for a transaction
  def update_savings_links(transaction, new_saving_ids)
    # Convert new_saving_ids to array of integers (empty/nil means uncheck all)
    new_saving_ids = Array(new_saving_ids).reject(&:blank?).map(&:to_i)
    existing_manual_links = transaction.saving_transactions.where(manual: true)

    # Process all existing links: update or remove
    existing_manual_links.each do |saving_transaction|
      if new_saving_ids.include?(saving_transaction.saving_id)
        # Recalculate amount if transaction changed
        new_amount = saving_transaction.saving.calculate_amount_for_transaction(transaction)

        if new_amount.nil?
          Savings::UnlinkTransactionService.call(saving_transaction.saving, transaction)
        elsif saving_transaction.amount_applied != new_amount
          saving_transaction.update!(amount_applied: new_amount)
        end
      else
        # Link no longer selected, remove it
        Savings::UnlinkTransactionService.call(saving_transaction.saving, transaction)
      end
    end

    # Add new links
    new_ids = new_saving_ids - existing_manual_links.pluck(:saving_id)
    link_to_savings(transaction, new_ids) if new_ids.any?
  end

  # Update debts links for a transaction
  def update_debts_links(transaction, new_debt_ids)
    # Convert new_debt_ids to array of integers (empty/nil means uncheck all)
    new_debt_ids = Array(new_debt_ids).reject(&:blank?).map(&:to_i)
    existing_manual_links = transaction.debt_transactions.where(manual: true)

    # Process all existing links: update or remove
    existing_manual_links.each do |debt_transaction|
      if new_debt_ids.include?(debt_transaction.debt_id)
        # Recalculate amount if transaction changed
        new_amount = debt_transaction.debt.calculate_amount_for_transaction(transaction)

        if new_amount.nil?
          Debts::UnlinkTransactionService.call(debt_transaction.debt, transaction)
        elsif debt_transaction.amount_applied != new_amount
          debt_transaction.update!(amount_applied: new_amount)
        end
      else
        # Link no longer selected, remove it
        Debts::UnlinkTransactionService.call(debt_transaction.debt, transaction)
      end
    end

    # Add new links
    new_ids = new_debt_ids - existing_manual_links.pluck(:debt_id)
    link_to_debts(transaction, new_ids) if new_ids.any?
  end
end
