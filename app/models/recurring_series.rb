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

  before_save :sync_cancelled_at, if: :will_save_change_to_status?

  scope :active,    -> { where(status: "active") }
  scope :detected,  -> { where(status: "detected") }
  scope :paused,    -> { where(status: "paused") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :due_on_or_before, ->(date) { where("next_due_date <= ?", date) }
  scope :upcoming_within, ->(days) { where(next_due_date: Date.current..Date.current + days.days) }

  # SQL fragments built ONCE at class load from the FREQUENCY_DAYS constant.
  # No user input ever touches these strings — all interpolated values are
  # Ruby-side literals defined in this file. Frozen at the class level so the
  # SQL is identical across every request.
  SIGNED_MONTHLY_SQL = begin
    branches = FREQUENCY_DAYS.map { |f, d| "WHEN frequency = '#{f}' THEN expected_amount * 30.0 / #{d}" }
    branches << "WHEN frequency = 'custom' THEN expected_amount * 30.0 / COALESCE(custom_interval_days, 30)"
    monthly = "(CASE #{branches.join(" ")} ELSE 0 END)"
    sign = "CASE WHEN transaction_type = 'income' THEN -1 ELSE 1 END"
    "#{monthly} * #{sign}"
  end.freeze

  MONTHLY_TOTAL_SQL = Arel.sql("COALESCE(SUM(#{SIGNED_MONTHLY_SQL}), 0)").freeze
  ANNUAL_TOTAL_SQL  = Arel.sql("COALESCE(SUM(#{SIGNED_MONTHLY_SQL} * 12), 0)").freeze
  TOTAL_COUNT_SQL   = Arel.sql("COUNT(*)").freeze

  # Computes monthly_total, annual_total, and count for a scope in a single SQL
  # aggregate. Income series contribute negatively (they reduce the net cost).
  # Custom-frequency series fall back to their custom_interval_days (or 30 if nil).
  def self.totals_for(scope)
    row = scope.pick(MONTHLY_TOTAL_SQL, ANNUAL_TOTAL_SQL, TOTAL_COUNT_SQL) || [ 0, 0, 0 ]
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

  private

  def sync_cancelled_at
    self.cancelled_at = status == "cancelled" ? (cancelled_at || Time.current) : nil
  end
end

# == Schema Information
#
# Table name: recurring_series
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_recurring_series_on_user_and_signature, index_recurring_series_on_user_id, index_recurring_series_on_user_id_and_next_due_date, index_recurring_series_on_user_id_and_status
#  name                 :string          not null   no default           no index
#  description_signature :string          not null   no default           index: index_recurring_series_on_user_and_signature
#  merchant_hint        :string          null       no default           no index
#  expected_amount      :decimal         not null   no default           no index
#  amount_variance_pct  :decimal         not null   default: 0.0         no index
#  frequency            :string          not null   no default           no index
#  custom_interval_days :integer         null       no default           no index
#  next_due_date        :date            not null   no default           index: index_recurring_series_on_user_id_and_next_due_date
#  last_charged_at      :date            null       no default           no index
#  last_notified_on     :date            null       no default           no index
#  category_id          :integer         null       no default           index: index_recurring_series_on_category_id
#  transaction_type     :string          not null   no default           no index
#  status               :string          not null   default: active      index: index_recurring_series_on_user_id_and_status
#  source               :string          not null   no default           no index
#  confidence_score     :integer         null       no default           no index
#  occurrences_count    :integer         not null   default: 0           no index
#  notes                :text            null       no default           no index
#  detected_at          :datetime        null       no default           no index
#  confirmed_at         :datetime        null       no default           no index
#  cancelled_at         :datetime        null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_recurring_series_on_category_id (category_id) non-unique
#  index_recurring_series_on_user_and_signature (user_id, description_signature) unique
#  index_recurring_series_on_user_id (user_id) non-unique
#  index_recurring_series_on_user_id_and_next_due_date (user_id, next_due_date) non-unique
#  index_recurring_series_on_user_id_and_status (user_id, status) non-unique
#
