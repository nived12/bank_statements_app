# frozen_string_literal: true

##
# Debts::TransactionBackfiller
# Links a debt's already-existing matching transactions — the ones that arrived
# before auto_sync, its categories/accounts, or opening_balance_date made them eligible.
# The inverse of TransactionAutoLinker: instead of "a transaction arrived, which debts
# want it", this asks "this debt just became eligible, which of its own past
# transactions can it already claim".
#
class Debts::TransactionBackfiller < ApplicationService
  # Each link costs a few queries and this runs inline in the request. A sweep this large
  # means the criteria are far too broad to be what the user meant, so stop and say so
  # rather than tie up the request linking thousands of rows.
  MAX_LINKS = 500

  def initialize(debt)
    super()
    @debt = debt
  end

  # Payload is { linked: Integer, skipped: Boolean }. `skipped` is what separates
  # "nothing matched" from "too much matched to run" — the user has to be told the
  # difference, or an over-broad criteria set fails invisibly.
  def call
    return nothing_to_do unless debt.auto_sync_transactions? && debt.status_active?
    return nothing_to_do if debt.category_ids.empty? || debt.bank_account_ids.empty?

    candidates = matching_transactions.to_a
    if candidates.size > MAX_LINKS
      Rails.logger.warn(
        "Skipped backfill for debt #{debt.id}: #{candidates.size} candidates exceeds MAX_LINKS (#{MAX_LINKS})"
      )
      return success(linked: 0, skipped: true)
    end

    success(linked: candidates.count { |transaction| link(transaction) }, skipped: false)
  end

  private

  attr_reader :debt

  def nothing_to_do
    success(linked: 0, skipped: false)
  end

  def matching_transactions
    debt.user.transactions
        .where(category_id: debt.category_ids, bank_account_id: debt.bank_account_ids)
        .relevant_for_balance(debt.opening_balance_date)
        .where.not(id: debt.debt_transactions.select(:transaction_id))
        .limit(MAX_LINKS + 1)
  end

  def link(transaction)
    amount_to_apply = debt.calculate_amount_for_transaction(transaction)
    return false if amount_to_apply.nil? || amount_to_apply.zero?

    Debts::TransactionLinker.call(debt, transaction, amount_to_apply, notes: "Auto-linked", manual: false).success?
  end
end
