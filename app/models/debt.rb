class Debt < ApplicationRecord
  include Discard::Model

  # Associations
  belongs_to :user
  belongs_to :category, optional: true
  belongs_to :bank_account, optional: true
  has_many :goal_debts, dependent: :destroy
  has_many :goals, through: :goal_debts
  has_many :debt_transactions, dependent: :destroy
  has_many :transactions, through: :debt_transactions, source: :transaction_record

  # Enums
  enum :status, {
    active: "active",
    paid_off: "paid_off",
    paused: "paused",
    archived: "archived"
  }, prefix: :status

  # Callbacks to sync status with discarded_at
  after_discard :set_archived_status
  after_undiscard :restore_active_status

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :original_amount, presence: true, numericality: { greater_than: 0 }
  validates :current_balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }

  # Conditional validations
  validate :category_required_for_auto_link
  validate :bank_account_required_for_auto_link

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :paid_off, -> { where(status: "paid_off") }
  scope :paused, -> { where(status: "paused") }
  scope :archived, -> { where(status: "archived") }
  scope :with_auto_link, -> { where(auto_link_category: true) }
  scope :filtered_by_status, ->(status) { where(status: status) }
  scope :filtered_by_goal, ->(goal_id) { joins(:goals).where(goals: { id: goal_id }) }
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

  # Instance Methods

  # Calculate progress percentage (amount paid down)
  def progress_percentage
    return 100 if original_amount.blank? || original_amount.zero?
    return 0 if current_balance >= original_amount

    total_paid = original_amount - current_balance
    ((total_paid.to_f / original_amount.to_f) * 100).round(2)
  end

  # Calculate amount paid down
  def amount_paid
    return 0 if original_amount.blank?

    original_amount - current_balance
  end

  # Calculate amount remaining to pay off
  def amount_remaining
    current_balance
  end

  # Check if debt is on track (simplified version)
  def on_track?
    return true if status_paid_off?

    current_balance >= 0 # For now, any positive balance is "on track"
  end

  # Calculate priority order based on goal's debt strategy
  def priority_order(goal)
    return nil unless goal&.debt_strategy.present?

    ordered_debts = case goal.debt_strategy
    when "snowball"
      goal.debts.active.order(:current_balance)
    when "avalanche"
      goal.debts.active.order(interest_rate: :desc)
    end

    ordered_debts.pluck(:id).index(id)&.+ 1
  end

  # Check if this debt has the highest priority for a specific goal
  def is_highest_priority?(goal)
    priority_order(goal) == 1
  end

  # Action: Mark debt as paid off
  def mark_paid_off!
    update!(
      status: "paid_off",
      current_balance: 0
    )
  end

  # Action: Pause debt
  def pause!
    update!(status: "paused")
  end

  # Action: Resume debt
  def resume!
    update!(status: "active")
  end

  # Action: Archive debt
  def archive!
    update!(status: "archived")
  end

  # Recalculate current_balance from linked transactions
  def recalculate_current_balance!
    total_paid = debt_transactions.sum(:amount_applied)
    new_balance = original_amount.to_f - total_paid
    new_balance = [new_balance, 0].max # Don't go below zero

    update_column(:current_balance, new_balance)

    # Mark as paid off if balance reaches zero
    if new_balance.zero? && status_active?
      mark_paid_off!
    end
  end

  # Calculate amount to apply for a transaction based on calculation_settings
  # Returns positive, negative, or nil (for ignore)
  def calculate_amount_for_transaction(transaction)
    settings = calculation_settings || {}
    tx_type = map_transaction_type_to_setting_key(transaction.transaction_type)

    # Get the setting for this transaction type
    setting = settings[tx_type]

    return nil if setting.nil? || setting == "ignore"

    case setting
    when "positive"
      transaction.amount.abs
    when "negative"
      -transaction.amount.abs
    else
      nil
    end
  end

  # Check if transaction date is within any goal's active period
  def transaction_within_date_range?(transaction)
    return true if goals.empty? # No goals, accept all dates
    return false if transaction.date.blank?

    goals.any? { |goal| transaction.date >= goal.start_date && transaction.date <= goal.deadline }
  end

  private

  def map_transaction_type_to_setting_key(transaction_type)
    case transaction_type
    when "income"
      "income"
    when "fixed_expense", "variable_expense"
      "expense"
    when "transfer_in"
      "transfer_in"
    when "transfer_out"
      "transfer_out"
    else
      transaction_type
    end
  end

  def set_defaults
    self.status ||= "active"
    self.current_balance ||= original_amount || 0
    self.auto_link_category ||= false
    self.calculation_settings ||= {}
  end

  def category_required_for_auto_link
    if auto_link_category? && category_id.blank?
      errors.add(:category_id, :required_for_auto_link)
    end
  end

  def bank_account_required_for_auto_link
    if auto_link_category? && bank_account_id.blank?
      errors.add(:bank_account_id, :required_for_auto_link)
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
#  category_id          :integer         null       no default           index: index_debts_on_category_id
#  bank_account_id      :integer         null       no default           index: index_debts_on_bank_account_id
#  name                 :string          not null   no default           no index
#  original_amount      :decimal         null       no default           no index
#  current_balance      :decimal         not null   no default           no index
#  interest_rate        :decimal         null       no default           no index
#  minimum_payment      :decimal         null       no default           no index
#  auto_link_category   :boolean         not null   default: false       no index
#  calculation_settings :jsonb           not null   default: {}          no index
#  status               :string          not null   default: active      no index
#  notes                :text            null       no default           no index
#  discarded_at         :datetime        null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  icon                 :string          null       no default           no index
#  color                :string          null       default: #EF4444     no index
#
# Indexes:
#  index_debts_on_bank_account_id (bank_account_id) non-unique
#  index_debts_on_category_id     (category_id) non-unique
#  index_debts_on_user_id         (user_id) non-unique
#
