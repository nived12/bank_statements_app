# frozen_string_literal: true

##
# Debts::Updater
# Updates an existing debt
#
class Debts::Updater < ApplicationService
  def initialize(debt, debt_params)
    super()
    @debt = debt
    @debt_params = debt_params.to_h.deep_transform_values(&:presence)
  end

  def call
    # Extract category and bank account IDs to set before update
    category_ids = @debt_params.delete(:category_ids)&.compact_blank || []
    bank_account_ids = @debt_params.delete(:bank_account_ids)&.compact_blank || []

    old_opening_balance_date = @debt.opening_balance_date
    old_auto_sync = @debt.auto_sync_transactions?
    categories_changing = category_ids.sort != @debt.category_ids.sort
    bank_accounts_changing = bank_account_ids.sort != @debt.bank_account_ids.sort

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      # Set associations BEFORE update (ensures validation passes if auto_sync is being enabled)
      @debt.category_ids = category_ids
      @debt.bank_account_ids = bank_account_ids
      @debt.update!(@debt_params)

      re_anchor_and_backfill!(old_opening_balance_date, old_auto_sync, categories_changing, bank_accounts_changing)
    end

    success(@debt)
  rescue ActiveRecord::RecordInvalid
    # Add validation errors to the service's error bag
    @debt.errors.each do |error|
      errors.add(error.attribute, error.message)
    end

    # Return the debt object as payload for error display
    Response.new(success: false, payload: @debt, errors: errors)
  end

  private

  attr_reader :debt, :debt_params

  # Runs after the update commits its own attributes, still inside the same DB transaction.
  # Moving opening_balance_date forward means some already-linked transactions are now
  # inside the retyped opening_balance and must be unlinked to avoid double counting.
  # Any other eligibility change (date, categories, accounts, auto-sync just turned on)
  # gets a backfill pass for transactions newly in reach.
  def re_anchor_and_backfill!(old_opening_balance_date, old_auto_sync, categories_changing, bank_accounts_changing)
    date_changed = debt.opening_balance_date != old_opening_balance_date
    date_moved_forward = date_changed && debt.opening_balance_date > old_opening_balance_date
    auto_sync_turned_on = debt.auto_sync_transactions? && !old_auto_sync

    unlinked = date_moved_forward ? unlink_now_covered_transactions : 0

    should_backfill = date_changed || auto_sync_turned_on || categories_changing || bank_accounts_changing
    linked = should_backfill ? Debts::TransactionBackfiller.call(debt).payload.to_i : 0

    return unless unlinked.positive? || linked.positive?

    debt.reload
    debt.backfill_summary = { linked: linked, unlinked: unlinked }
  end

  def unlink_now_covered_transactions
    debt.debt_transactions.joins(:transaction_record)
        .merge(Transaction.historical(debt.opening_balance_date))
        .destroy_all
        .size
  end
end
