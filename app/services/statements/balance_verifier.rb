# frozen_string_literal: true

##
# Checks the one thing every statement guarantees about itself: that its own movements
# reach its own closing figure. It cannot say which row was read wrongly, only that the
# total no longer reconciles — but it can say that for any bank in any language,
# including ones that do not exist yet. Advisory: never blocks an import.
#
class Statements::BalanceVerifier < ApplicationService
  TOLERANCE = 1.0

  # A brokerage is absent on purpose: its declared value is the portfolio, which moves
  # with the market and so cannot be reached from a ledger of cash movements.
  VERIFIABLE_TYPES = %w[debit credit].freeze

  def initialize(statement_file)
    super()
    @statement_file = statement_file
  end

  def call
    return skip unless verifiable?

    expected = summary.final_balance
    discrepancy = smallest_discrepancy(expected)
    balanced = discrepancy.abs <= TOLERANCE

    record(balanced: balanced, discrepancy: discrepancy)
    log(balanced: balanced, discrepancy: discrepancy, expected: expected)

    success(balanced: balanced, discrepancy: discrepancy, skipped: false)
  rescue StandardError => e
    # Reported, not just logged. The check is advisory, so swallowing the error keeps a
    # broken verifier looking exactly like a statement it legitimately declined to judge —
    # and a feature whose whole job is catching what nobody notices would stop silently.
    Rails.logger.error("BalanceVerifier failed for statement #{statement_file.id}: #{e.message}")
    Sentry.capture_exception(e, extra: { statement_file_id: statement_file.id }) if defined?(Sentry)
    skip
  end

  private

  attr_reader :statement_file

  # How much is owed on a card is unambiguous; whether it is written 21,391.18 or
  # -21,391.18 is not. Banks print debt positive, this app displays it negative, and the
  # extraction has produced both. Since the sign is presentational, a card is balanced
  # when the magnitude matches either way.
  #
  # The cost is that a wholesale sign inversion across every row would still pass. That
  # trade is deliberate: missing or misread rows are the failure this catches, and they
  # are common, whereas an inverted ledger breaks far more loudly elsewhere.
  def smallest_discrepancy(expected)
    reached = reached_closing_balance
    candidates = statement_file.bank_account.credit? ? [expected, -expected] : [expected]

    candidates.map { |candidate| (reached - candidate).round(2) }.min_by(&:abs)
  end

  # Debit runs the obvious way: opening plus what moved. A card tracks debt, so its
  # charges raise the closing figure while being stored negative and its payments lower
  # it while being stored positive — the same sum, subtracted.
  #
  #   Santander, July 2026: 0.00 - (-21,391.18) = 21,391.18, the figure it printed.
  #   BBVA, June 2026:  21,635.77 - (-14,109.21) = 35,744.98, likewise.
  def reached_closing_balance
    movement = statement_file.transactions.sum(:amount)
    return summary.initial_balance - movement if statement_file.bank_account.credit?

    summary.initial_balance + movement
  end

  def verifiable?
    VERIFIABLE_TYPES.include?(statement_file.bank_account&.account_type) &&
      summary.present? &&
      summary.initial_balance.present? &&
      summary.final_balance.present? &&
      !undeclared_balances?
  end

  # FinancialSummaryCreator stores 0.0 for a key the AI never emitted, so a statement
  # that opens and closes at zero while carrying rows never declared its balances at all.
  def undeclared_balances?
    summary.initial_balance.zero? &&
      summary.final_balance.zero? &&
      statement_file.transactions.exists?
  end

  def summary
    @summary ||= statement_file.financial_summary
  end

  def skip
    success(balanced: nil, discrepancy: nil, skipped: true)
  end

  # Persisted, not just logged, so "which statements did we get wrong" stays answerable.
  def record(balanced:, discrepancy:)
    data = summary.statement_type_data || {}
    summary.update_columns(
      statement_type_data: data.merge(
        "balance_check" => {
          "balanced" => balanced,
          "discrepancy" => discrepancy.to_f,
          "checked_at" => Time.current.iso8601
        }
      )
    )
  end

  def log(balanced:, discrepancy:, expected:)
    return Rails.logger.info("Statement #{statement_file.id} balances") if balanced

    Rails.logger.warn(
      "Statement #{statement_file.id} does not balance: expected closing #{expected}, " \
      "off by #{discrepancy}. Transactions are likely misclassified or missing."
    )
  end
end
