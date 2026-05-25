# frozen_string_literal: true

class RecurringSeries < ApplicationRecord
  FREQUENCIES = %w[weekly biweekly monthly quarterly annual custom].freeze
  STATUSES    = %w[detected active paused cancelled].freeze
  SOURCES     = %w[manual detected].freeze
  TX_TYPES    = %w[income fixed_expense variable_expense].freeze

  FREQUENCY_DAYS = {
    "weekly" => 7,
    "biweekly" => 14,
    "monthly" => 30,
    "quarterly" => 91,
    "annual" => 365
  }.freeze

  belongs_to :user
  belongs_to :category, optional: true
  has_many   :transactions, dependent: :nullify

  validates :name, :description_signature, :expected_amount, :frequency,
    :next_due_date, :transaction_type, :status, :source, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :transaction_type, inclusion: { in: TX_TYPES }
  validates :expected_amount, numericality: { greater_than: 0 }
  validates :custom_interval_days, numericality: { greater_than: 0, only_integer: true },
    if: -> { frequency == "custom" }
  validates :description_signature, uniqueness: { scope: :user_id }

  scope :active,    -> { where(status: "active") }
  scope :detected,  -> { where(status: "detected") }
  scope :paused,    -> { where(status: "paused") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :due_on_or_before, ->(date) { where("next_due_date <= ?", date) }
  scope :upcoming_within, ->(days) { where(next_due_date: Date.current..Date.current + days.days) }

  # Computes monthly_total, annual_total, and count for a scope in a single SQL
  # aggregate. Income series contribute negatively (they reduce the net cost).
  # Custom-frequency series fall back to their custom_interval_days (or 30 if
  # somehow nil) — the literal interpolation is safe because FREQUENCY_DAYS is
  # a Ruby-side constant, not user input.
  def self.totals_for(scope)
    case_branches = FREQUENCY_DAYS.map { |f, d| "WHEN frequency = '#{f}' THEN expected_amount * 30.0 / #{d}" }
    case_branches << "WHEN frequency = 'custom' THEN expected_amount * 30.0 / COALESCE(custom_interval_days, 30)"
    joined = case_branches.join(" ")
    monthly = "(CASE #{joined} ELSE 0 END)"
    sign = "CASE WHEN transaction_type = 'income' THEN -1 ELSE 1 END"
    signed_monthly = "#{monthly} * #{sign}"

    row = scope.pick(
      Arel.sql("COALESCE(SUM(#{signed_monthly}), 0)"),
      Arel.sql("COALESCE(SUM(#{signed_monthly} * 12), 0)"),
      Arel.sql("COUNT(*)")
    ) || [ 0, 0, 0 ]
    { monthly_total: row[0].to_f.round(2), annual_total: row[1].to_f.round(2), count: row[2].to_i }
  end

  def interval_days
    return custom_interval_days || 30 if frequency == "custom"

    FREQUENCY_DAYS[frequency] || 30
  end

  def advance_due_date!
    update!(next_due_date: next_due_date + interval_days.days)
  end

  def monthly_estimate
    (expected_amount * 30 / interval_days).round(2)
  end

  def annual_estimate
    (expected_amount * 365 / interval_days).round(2)
  end
end
