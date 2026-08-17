# frozen_string_literal: true

##
# Types a brokerage's internal churn — repo rollovers, share purchases — as `investment`
# so it stops counting as income and spending.
#
# Matches on nothing: no wording, no regex. Wording differs between every broker and
# would break silently on the next one. It relies instead on running *after* the transfer
# reconciler, which is the evidence a row crossed the account boundary — anything left
# typed income or expense on a brokerage did not cross.
#
# Known limit: a dividend is real income and gets swept up here too. On the brokerage
# statements measured so far that is cents against tens of thousands of noise removed,
# and the row stays editable.
#
class Transactions::InvestmentClassifier < ApplicationService
  RETYPEABLE = %w[income fixed_expense variable_expense].freeze

  def initialize(statement_file)
    super()
    @statement_file = statement_file
  end

  def call
    return success(0) unless investment_account?

    ids = candidates.pluck(:id)
    return success(0) if ids.empty?

    retype(ids)
    Rails.logger.info("Typed #{ids.size} rows as investment on statement #{statement_file.id}")
    success(ids.size)
  end

  private

  attr_reader :statement_file

  def investment_account?
    statement_file.bank_account&.account_type == "investment"
  end

  def candidates
    statement_file.transactions
                  .where(transaction_type: RETYPEABLE)
                  .where(linked_transfer_id: nil)
  end

  # update_all because Transaction's auto_link callback re-links rather than unlinks, so
  # the auto-created savings/debt links are cleared here. Manual links are the user's.
  def retype(ids)
    ActiveRecord::Base.transaction do
      Transaction.where(id: ids).update_all(transaction_type: "investment")
      SavingTransaction.where(transaction_id: ids, manual: false).destroy_all
      DebtTransaction.where(transaction_id: ids, manual: false).destroy_all
    end
  end
end
