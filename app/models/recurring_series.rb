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

  def interval_days
    frequency == "custom" ? custom_interval_days : FREQUENCY_DAYS[frequency]
  end

  def advance_due_date!
    update!(next_due_date: next_due_date + interval_days.days)
  end

  def monthly_estimate
    days = interval_days || 30
    (expected_amount * 30 / days).round(2)
  end

  def annual_estimate
    days = interval_days || 30
    (expected_amount * 365 / days).round(2)
  end
end
