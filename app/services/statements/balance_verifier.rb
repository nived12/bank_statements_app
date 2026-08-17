# frozen_string_literal: true

##
# Checks the one thing every statement guarantees about itself:
#
#   saldo inicial + Σ movimientos == saldo final
#
# It cannot say which row was read wrongly, only that the total no longer reconciles —
# but it can say that for any bank in any language, including ones that do not exist
# yet. Advisory: it records what it found and never blocks an import.
#
class Statements::BalanceVerifier < ApplicationService
  TOLERANCE = 1.0

  # A card statement tracks debt, so charges raise the closing figure while being stored
  # negative and the sum runs the wrong way. A brokerage declares portfolio value, which
  # moves with the market and so cannot be derived from a ledger of cash movements.
  # Flagging either every time would train the reader to ignore the signal.
  VERIFIABLE_TYPES = %w[debit].freeze

  def initialize(statement_file)
    super()
    @statement_file = statement_file
  end

  def call
    return skip unless verifiable?

    expected = summary.final_balance
    actual = summary.initial_balance + statement_file.transactions.sum(:amount)
    discrepancy = (actual - expected).round(2)
    balanced = discrepancy.abs <= TOLERANCE

    record(balanced: balanced, discrepancy: discrepancy)
    log(balanced: balanced, discrepancy: discrepancy, expected: expected)

    success(balanced: balanced, discrepancy: discrepancy, skipped: false)
  rescue StandardError => e
    Rails.logger.error("BalanceVerifier failed for statement #{statement_file.id}: #{e.message}")
    skip
  end

  private

  attr_reader :statement_file

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
