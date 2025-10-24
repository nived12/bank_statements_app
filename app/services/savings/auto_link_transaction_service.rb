# frozen_string_literal: true

##
# Savings::AutoLinkTransactionService
# Automatically links transactions to savings based on matching criteria
# and calculation_settings
#
class Savings::AutoLinkTransactionService < ApplicationService
  def initialize(transaction)
    super()
    @transaction = transaction
  end

  def call
    return success if skip_auto_linking?

    matching_savings = find_matching_savings

    matching_savings.each do |saving|
      auto_link_to_saving(saving)
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
    return true if SavingTransaction.where(transaction_id: transaction.id, manual: true).exists?

    false
  end

  def find_matching_savings
    # Active savings with auto_link enabled, matching bank_account + category
    # LEFT JOIN goals to check if transaction date falls within goal date range
    Saving.with_auto_link
          .active
          .left_joins(:goals)
          .where(bank_account_id: transaction.bank_account_id)
          .where(category_id: transaction.category_id)
          .where("(goals.id IS NULL OR (goals.start_date <= ? AND goals.deadline >= ?))",
                 transaction.date, transaction.date)
          .distinct
  end

  def auto_link_to_saving(saving)
    # Use saving's own calculate_amount_for_transaction method
    amount_to_apply = saving.calculate_amount_for_transaction(transaction)

    # Skip if amount is nil (ignore setting) or zero
    return if amount_to_apply.nil? || amount_to_apply.zero?

    # Use existing LinkTransactionService
    result = Savings::LinkTransactionService.call(
      saving,
      transaction,
      amount_to_apply, # Can be positive or negative based on calculation_settings
      notes: "Auto-linked",
      manual: false
    )

    # Log errors but don't fail the whole operation
    unless result.success?
      Rails.logger.warn(
        "Failed to auto-link transaction #{transaction.id} to saving #{saving.id}: " \
        "#{result.errors.full_messages.join(", ")}"
      )
    end
  end
end
