class Debt < ApplicationRecord
  include Discard::Model
  include Periodable
  include DebtCalculations
  include DebtPaymentSchedule
  include DebtProgress
  include DebtTransactions
  include DebtStatusActions

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

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :original_amount, presence: true, numericality: { greater_than: 0 }
  validates :current_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validates :due_day_of_month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31, allow_nil: true }
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
  scope :filtered_by_status, ->(status) { where(status: status) }
  scope :filtered_by_goal, ->(goal_id) { joins(:goals).where(goals: { id: goal_id }) }
  scope :with_due_date, -> { where.not(due_day_of_month: nil) }
  scope :ordered_by_priority, ->(goal_id) {
    joins(:goals)
      .where(goals: { id: goal_id })
      .order(
        Arel.sql("CASE goals.debt_strategy
          WHEN 'snowball' THEN debts.current_balance
          WHEN 'avalanche' THEN debts.interest_rate DESC
          ELSE debts.created_at DESC
        END")
      )
  }

  # Callbacks
  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.status ||= "active"
    self.current_balance ||= original_amount || 0
    self.auto_sync_transactions ||= false
    self.calculation_settings ||= {}
  end

  def categories_required_for_auto_sync
    # Skip validation on create - associations will be validated in the service
    return if new_record?

    if auto_sync_transactions? && categories.empty?
      errors.add(:base, :categories_required_for_auto_sync, message: "At least one category is required when auto-sync is enabled")
    end
  end

  def bank_accounts_required_for_auto_sync
    # Skip validation on create - associations will be validated in the service
    return if new_record?

    if auto_sync_transactions? && bank_accounts.empty?
      errors.add(:base, :bank_accounts_required_for_auto_sync, message: "At least one bank account is required when auto-sync is enabled")
    end
  end

  def set_archived_status
    update_column(:status, "archived")
  end

  def restore_active_status
    # Restore to active status when unarchiving, unless it was paid off
    update_column(:status, "active") unless status_paid_off?
  end
end

# == Schema Information
#
# Table name: debts
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_debts_on_user_id
#  name                 :string          not null   no default           no index
#  original_amount      :decimal         null       no default           no index
#  current_balance      :decimal         not null   no default           no index
#  interest_rate        :decimal         null       no default           no index
#  minimum_payment      :decimal         null       no default           no index
#  calculation_settings :jsonb           not null   default: {}          no index
#  status               :string          not null   default: active      no index
#  notes                :text            null       no default           no index
#  discarded_at         :datetime        null       no default           no index
#  created_at           :datetime        not null   no default           no index
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
#
