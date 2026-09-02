# frozen_string_literal: true

##
# CategoryRules::Backfiller
# Re-applies a user's category rules to transactions that were already imported.
#
# Rules only ran at import time, so a rule taught after a statement was processed —
# or one that could not match until word-order matching landed — never reached the
# rows it was meant to fix. Defaults to a preview; nothing is written unless
# apply: true, because a rule's category cannot be told apart from one the user set
# by hand afterwards.
#
class CategoryRules::Backfiller < ApplicationService
  # A whole statement history does not need to be resident to match one row against the
  # rules, and for a long-standing user it is the largest table they own.
  BATCH_SIZE = 500

  def initialize(user:, apply: false)
    super()
    @user = user
    @apply = apply
  end

  def call
    changes = []

    transactions.in_batches(of: BATCH_SIZE) do |batch|
      rows = batch.to_a
      changes.concat(rows.zip(match(rows)).filter_map { |transaction, candidate| change_for(transaction, candidate) })
    end

    # in_batches orders by primary key, so the date order the preview reads by has to be
    # restored here. Sorting the changes rather than the rows keeps it off the full history.
    changes.sort_by! { |change| change[:date] }
    apply_changes(changes) if @apply

    success(changes: changes, applied: @apply)
  end

  private

  def transactions
    @user.transactions.where(source: :statement_file)
  end

  # One matcher call for the whole run, not one per row: Matcher reloads the user's rules
  # on every invocation, so matching row by row means a rules query per transaction.
  def match(rows)
    candidates = rows.map { |transaction| { "description" => transaction.description } }
    return candidates if candidates.empty?

    CategoryRules::Matcher.call(user: @user, transactions: candidates, record_hits: false)
    candidates
  end

  def change_for(transaction, candidate)
    return nil if candidate["matched_rule_id"].blank?

    target_id = candidate["sub_category_id"].presence || candidate["category_id"]
    return nil if target_id.blank? || target_id == transaction.category_id

    {
      transaction_id: transaction.id,
      date: transaction.date,
      description: transaction.description,
      from_category_id: transaction.category_id,
      to_category_id: target_id,
      rule_id: candidate["matched_rule_id"]
    }
  end

  def apply_changes(changes)
    changes.each do |change|
      # update! rather than update_all: the auto-link callback is what moves the row
      # onto the matching debt or saving.
      @user.transactions.find(change[:transaction_id]).update!(category_id: change[:to_category_id])
    end

    changes.map { |change| change[:rule_id] }.compact.tally.each do |rule_id, count|
      CategoryRule.where(id: rule_id).update_all([ "hits_count = hits_count + ?", count ])
    end
  end
end
