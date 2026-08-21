# frozen_string_literal: true

##
# Savings::TransactionBackfiller
# Links a saving's already-existing matching transactions — the ones that arrived
# before auto_sync, its categories/accounts, or opening_balance_date made them eligible.
# The inverse of TransactionAutoLinker: instead of "a transaction arrived, which savings
# want it", this asks "this saving just became eligible, which of its own past
# transactions can it already claim".
#
class Savings::TransactionBackfiller < ApplicationService
  # Each link costs a few queries and this runs inline in the request. A sweep this large
  # means the criteria are far too broad to be what the user meant, so stop and say so
  # rather than tie up the request linking thousands of rows.
  MAX_LINKS = 500

  def initialize(saving)
    super()
    @saving = saving
  end

  def call
    return success(0) unless saving.auto_sync_transactions? && saving.status_active?
    return success(0) if saving.category_ids.empty? || saving.bank_account_ids.empty?

    candidates = matching_transactions.to_a
    if candidates.size > MAX_LINKS
      Rails.logger.warn(
        "Skipped backfill for saving #{saving.id}: #{candidates.size} candidates exceeds MAX_LINKS (#{MAX_LINKS})"
      )
      return success(0)
    end

    linked_count = candidates.count { |transaction| link(transaction) }
    success(linked_count)
  end

  private

  attr_reader :saving

  def matching_transactions
    saving.user.transactions
          .where(category_id: saving.category_ids, bank_account_id: saving.bank_account_ids)
          .relevant_for_balance(saving.opening_balance_date)
          .where.not(id: saving.saving_transactions.select(:transaction_id))
          .limit(MAX_LINKS + 1)
  end

  def link(transaction)
    amount_to_apply = saving.calculate_amount_for_transaction(transaction)
    return false if amount_to_apply.nil? || amount_to_apply.zero?

    Savings::TransactionLinker.call(saving, transaction, amount_to_apply, notes: "Auto-linked", manual: false).success?
  end
end
