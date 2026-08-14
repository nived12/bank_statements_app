# frozen_string_literal: true

##
# Transactions::ExcludedPairMarker
#
# Marks pairs of rows on a credit-card statement that undo each other: a charge and
# the credit that reverses it. Cards do this when a purchase is re-billed as meses
# sin intereses, refunded, or settled with points — the original charge is credited
# back and the real cost arrives later as installments.
#
# Left alone, the credit is read as income (statements word it "ABONO") while the
# charge still counts as spending, so a single purchase inflates both totals at once.
# July 2026 carried $6,786.12 of income that was never money.
#
# Matched on **amount, not wording**. An audit across every user found the same event
# described as "ABONO CARGO TRASPASADO CCUOTAS", "PAGOS CON PUNTOS", "CASHBACK" and a
# bare merchant refund — no regex was going to cover that, and each new bank would
# break it silently. Of 53 positive rows on 18 credit accounts, exactly four cancelled
# a charge exactly, and all four should; none of the 48 card payments matched anything.
#
class Transactions::ExcludedPairMarker < ApplicationService
  def initialize(statement_file)
    super()
    @statement_file = statement_file
  end

  def call
    return success(0) unless credit_card?

    cancelled = 0

    credits.each do |credit|
      charge = sole_matching_charge(credit)
      next if charge.nil?

      exclude(charge, credit)
      @claimed << charge.id
      cancelled += 1
    end

    success(cancelled)
  end

  private

  attr_reader :statement_file

  def credit_card?
    statement_file.bank_account&.account_type == "credit"
  end

  # Rows already paired as a transfer are somebody else's business — the reconciler
  # linked them to a counterpart on another account, and re-typing them here would
  # break that pairing.
  def candidates
    @candidates ||= statement_file.transactions
      .where(transaction_type: %w[income fixed_expense variable_expense])
      .where(linked_transfer_id: nil)
      .to_a
  end

  def credits
    @claimed = Set.new
    candidates.select { |t| t.amount.positive? }
  end

  # Exactly one charge, or nothing. Two purchases of the same amount and one credit is
  # genuinely ambiguous — the same reasoning that stops the transfer reconciler picking
  # between two indistinguishable candidates.
  def sole_matching_charge(credit)
    matches = candidates.select do |t|
      t.amount.negative? && t.amount.abs == credit.amount.abs && !@claimed.include?(t.id)
    end

    matches.one? ? matches.first : nil
  end

  def exclude(charge, credit)
    Transaction.where(id: [charge.id, credit.id]).update_all(transaction_type: "excluded")
  end
end
