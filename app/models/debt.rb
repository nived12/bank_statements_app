class Debt < ApplicationRecord
  include Discard::Model
  include Periodable
  include DebtCalculations
  include DebtPaymentSchedule
  include DebtProgress
  include DebtTransactions
  include DebtStatusActions

  # Not persisted — set by Debts::Creator/Updater after a backfill or re-anchor unlink,
  # so the response can tell the UI what changed. nil on every plain read.
  attr_accessor :backfill_summary

  # Associations
  belongs_to :user
  has_many :debt_categories, dependent: :destroy
  has_many :categories, through: :debt_categories
  has_many :debt_bank_accounts, dependent: :destroy
  has_many :bank_accounts, through: :debt_bank_accounts
  has_many :goal_debts, dependent: :destroy
  has_many :goals, through: :goal_debts
  has_many :debt_transactions, dependent: :destroy
  has_many :transactions, through: :debt_transactions, source: :transaction_record

  # Nested attributes for handling category and bank account assignments
  accepts_nested_attributes_for :debt_categories, allow_destroy: true
  accepts_nested_attributes_for :debt_bank_accounts, allow_destroy: true

  # Enums
  enum :status, {
    active: "active",
    paid_off: "paid_off",
    paused: "paused",
    archived: "archived"
  }, prefix: :status

  enum :payment_frequency, {
    weekly: "weekly",
    biweekly: "biweekly",
    semimonthly: "semimonthly",
    monthly: "monthly"
  }, prefix: :frequency, default: :monthly

  enum :payment_mode, {
    fixed: "fixed",
    calculated: "calculated"
  }, prefix: :mode

  # Callbacks to sync status with discarded_at
  after_discard :set_archived_status
  after_undiscard :restore_active_status
  before_validation :normalize_numeric_fields
  after_save :auto_update_status_based_on_balance, if: :saved_change_to_current_balance?

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :original_amount, presence: true, numericality: { greater_than: 0 }
  validates :current_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :due_day_of_month,
    numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31,
allow_nil: true }
  validates :target_payment_amount, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  # Conditional validations
  validate :categories_required_for_auto_sync
  validate :bank_accounts_required_for_auto_sync
  validates :target_payoff_date, presence: true, if: -> { payment_mode == "calculated" }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :paid_off, -> { where(status: "paid_off") }
  scope :paused, -> { where(status: "paused") }
  scope :archived, -> { where(status: "archived") }
  scope :with_auto_sync, -> { where(auto_sync_transactions: true) }
  scope :filter_by_status, ->(status) { where(status: status) }
  scope :filter_by_goal, ->(goal_id) { joins(:goals).where(goals: { id: goal_id }) }
  scope :with_due_date, -> { where.not(due_day_of_month: nil) }
  scope :sort_by_priority, -> {
    joins(:goals)
      .order(
        Arel.sql(
          "CASE goals.debt_strategy
          WHEN 'snowball' THEN debts.current_balance
          WHEN 'avalanche' THEN debts.interest_rate DESC
          ELSE debts.created_at DESC
        END"
        )
      )
  }

  # Callbacks
  after_initialize :set_defaults, if: :new_record?
  # FactoryBot (and anything else that builds via `.new` then sets attributes one at a
  # time, rather than `.new(all_attrs)`) assigns original_amount AFTER after_initialize
  # runs — set_defaults would see it still nil. before_validation runs once every
  # attribute has settled, regardless of how the record was built.
  before_validation :default_amounts, if: :new_record?

  private

  def set_defaults
    self.status ||= "active"
    self.opening_balance_date ||= Date.current
    self.auto_sync_transactions ||= false
    self.calculation_settings ||= {}
  end

  def default_amounts
    self.opening_balance ||= original_amount || 0
    self.current_balance ||= opening_balance
  end

  def categories_required_for_auto_sync
    if auto_sync_transactions? && categories.empty?
      errors.add(:base, I18n.t("debts.errors.categories_required_for_auto_sync"))
    end
  end

  def bank_accounts_required_for_auto_sync
    if auto_sync_transactions? && bank_accounts.empty?
      errors.add(:base, I18n.t("debts.errors.bank_accounts_required_for_auto_sync"))
    end
  end

  def set_archived_status
    update_column(:status, "archived")
  end

  def restore_active_status
    # Restore to active status when unarchiving, unless it was paid off
    update_column(:status, "active") unless status_paid_off?
  end

  def normalize_numeric_fields
    # Remove commas and spaces from numeric fields (backup if JS fails)
    self.original_amount = original_amount.to_s.gsub(/[,\s]/, "") if original_amount.present?
    self.opening_balance = opening_balance.to_s.gsub(/[,\s]/, "") if opening_balance.present?
    self.interest_rate = interest_rate.to_s.gsub(/[,\s]/, "") if interest_rate.present?
    self.minimum_payment = minimum_payment.to_s.gsub(/[,\s]/, "") if minimum_payment.present?
    self.target_payment_amount = target_payment_amount.to_s.gsub(/[,\s]/, "") if target_payment_amount.present?
  end

  def auto_update_status_based_on_balance
    # Only auto-update between active and paid_off states
    # Don't touch paused or archived states (user explicitly set those)
    return unless status_active? || status_paid_off?

    if current_balance.zero? && status_active?
      update_column(:status, "paid_off")
    elsif current_balance.positive? && status_paid_off?
      update_column(:status, "active")
    end
  end
end

# == Schema Information
#
# Table name: debts
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_debts_on_user_id, index_debts_on_user_id_and_status_and_created_at
#  name                 :string          not null   no default           no index
#  original_amount      :decimal         null       no default           no index
#  current_balance      :decimal         not null   no default           no index
#  interest_rate        :decimal         null       no default           no index
#  minimum_payment      :decimal         null       no default           no index
#  calculation_settings :jsonb           not null   default: {}          no index
#  status               :string          not null   default: active      index: index_debts_on_user_id_and_status_and_created_at
#  notes                :text            null       no default           no index
#  discarded_at         :datetime        null       no default           no index
#  created_at           :datetime        not null   no default           index: index_debts_on_user_id_and_status_and_created_at
#  updated_at           :datetime        not null   no default           no index
#  icon                 :string          null       no default           no index
#  color                :string          null       default: #EF4444     no index
#  auto_sync_transactions :boolean         not null   default: false       no index
#  due_day_of_month     :integer         null       no default           index: index_debts_on_due_day_of_month
#  payment_frequency    :string          null       default: monthly     no index
#  payment_mode         :string          null       no default           no index
#  target_payment_amount :decimal         null       no default           no index
#  target_payoff_date   :date            null       no default           index: index_debts_on_target_payoff_date
#
# Indexes:
#  index_debts_on_due_day_of_month (due_day_of_month) non-unique
#  index_debts_on_target_payoff_date (target_payoff_date) non-unique
#  index_debts_on_user_id         (user_id) non-unique
#  index_debts_on_user_id_and_status_and_created_at (user_id, status, created_at) non-unique
#
