# frozen_string_literal: true

##
# Debts::AutoLinkTransactionService
# Automatically links transactions to debts based on matching criteria
# and calculation_settings
#
class Debts::AutoLinkTransactionService < ApplicationService
  def initialize(transaction)
    super()
    @transaction = transaction
  end

  def call
    return success if skip_auto_linking?

    matching_debts = find_matching_debts

    matching_debts.each do |debt|
      auto_link_to_debt(debt)
    end

    success
  end

  private

  attr_reader :transaction

  def skip_auto_linking?
    # Skip if no category or bank account
    return true if transaction.category_id.blank?
    return true if transaction.bank_account_id.blank?

    # Skip if transaction has any manual links (manual linking takes precedence)
    # Query database directly to avoid association caching issues
    return true if DebtTransaction.where(transaction_id: transaction.id, manual: true).exists?

    false
  end

  def find_matching_debts
    # Active debts with auto_link enabled, matching bank_account + category
    Debt.with_auto_link
        .active
        .where(bank_account_id: transaction.bank_account_id)
        .where(category_id: transaction.category_id)
        .where("(goals.id IS NULL OR EXISTS (SELECT 1 FROM goal_debts gd JOIN goals ON goals.id = gd.goal_id WHERE gd.debt_id = debts.id AND goals.start_date <= ? AND goals.deadline >= ?))",
               transaction.date, transaction.date)
  end

  def auto_link_to_debt(debt)
    # Use debt's own calculate_amount_for_transaction method
    amount_to_apply = debt.calculate_amount_for_transaction(transaction)

    # Skip if amount is nil (ignore setting) or zero
    return if amount_to_apply.nil? || amount_to_apply.zero?

    # Use existing LinkTransactionService
    result = Debts::LinkTransactionService.call(
      debt,
      transaction,
      amount_to_apply, # Can be positive or negative based on calculation_settings
      notes: "Auto-linked",
      manual: false
    )

    # Log errors but don't fail the whole operation
    unless result.success?
      Rails.logger.warn(
        "Failed to auto-link transaction #{transaction.id} to debt #{debt.id}: " \
        "#{result.errors.full_messages.join(", ")}"
      )
    end
  end
end
