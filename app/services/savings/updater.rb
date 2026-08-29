# frozen_string_literal: true

##
# Savings::Updater
# Updates an existing saving
#
class Savings::Updater < ApplicationService
  def initialize(saving, saving_params)
    super()
    @saving = saving
    # Only blank strings become nil. Bare `&:presence` also turned false into
    # nil, and auto_sync_transactions is NOT NULL — every mobile edit of a
    # record with auto-sync off raised a 500.
    @saving_params = saving_params.to_h.deep_transform_values { |value| value.is_a?(String) ? value.presence : value }
  end

  def call
    # Extract category and bank account IDs to set before update
    # Cast to Integer before comparing: params arrive as strings, and ["1"] != [1] would
    # mark the associations changed on every save, firing a backfill that isn't needed.
    category_ids = (@saving_params.delete(:category_ids)&.compact_blank || []).map(&:to_i)
    bank_account_ids = (@saving_params.delete(:bank_account_ids)&.compact_blank || []).map(&:to_i)

    old_opening_balance_date = @saving.opening_balance_date
    old_auto_sync = @saving.auto_sync_transactions?
    categories_changing = category_ids.sort != @saving.category_ids.sort
    bank_accounts_changing = bank_account_ids.sort != @saving.bank_account_ids.sort

    # Wrap in transaction for atomicity - either everything succeeds or nothing persists
    ActiveRecord::Base.transaction do
      # Set associations BEFORE update (ensures validation passes if auto_sync is being enabled)
      @saving.category_ids = category_ids
      @saving.bank_account_ids = bank_account_ids
      @saving.update!(@saving_params)

      re_anchor_and_backfill!(old_opening_balance_date, old_auto_sync, categories_changing, bank_accounts_changing)
    end

    success(@saving)
  rescue ActiveRecord::RecordInvalid
    # Add validation errors to the service's error bag
    @saving.errors.each do |error|
      errors.add(error.attribute, error.message)
    end

    # Return the saving object as payload for error display
    Response.new(success: false, payload: @saving, errors: errors)
  end

  private

  attr_reader :saving, :saving_params

  # Runs after the update commits its own attributes, still inside the same DB transaction.
  # Moving opening_balance_date forward means some already-linked transactions are now
  # inside the retyped opening_balance and must be unlinked to avoid double counting.
  # Any other eligibility change (date, categories, accounts, auto-sync just turned on)
  # gets a backfill pass for transactions newly in reach.
  def re_anchor_and_backfill!(old_opening_balance_date, old_auto_sync, categories_changing, bank_accounts_changing)
    date_changed = saving.opening_balance_date != old_opening_balance_date
    date_moved_forward = date_changed && saving.opening_balance_date > old_opening_balance_date
    auto_sync_turned_on = saving.auto_sync_transactions? && !old_auto_sync

    unlinked = date_moved_forward ? unlink_now_covered_transactions : 0

    # A date that only moved forward narrows the eligible window, so nothing can newly
    # qualify — skip the backfill unless some other criterion widened it too.
    should_backfill = (date_changed && !date_moved_forward) ||
                      auto_sync_turned_on || categories_changing || bank_accounts_changing
    backfill = should_backfill ? Savings::TransactionBackfiller.call(saving).payload : { linked: 0, skipped: false }
    linked = backfill[:linked].to_i

    return unless unlinked.positive? || linked.positive? || backfill[:skipped]

    saving.reload
    saving.backfill_summary = { linked: linked, unlinked: unlinked, skipped: backfill[:skipped] }
  end

  # destroy_all rather than delete_all: each after_destroy recalculates the amount, so
  # this costs one extra write per row. Kept deliberately — the callback is the only
  # thing keeping current_amount correct, and re-anchoring is rare.
  def unlink_now_covered_transactions
    saving.saving_transactions.joins(:transaction_record)
          .merge(Transaction.historical(saving.opening_balance_date))
          .destroy_all
          .size
  end
end
