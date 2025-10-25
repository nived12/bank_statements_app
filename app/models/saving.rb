class Saving < ApplicationRecord
  include Discard::Model

  # Associations
  belongs_to :user
  has_many :saving_categories, dependent: :destroy
  has_many :categories, through: :saving_categories
  has_many :saving_bank_accounts, dependent: :destroy
  has_many :bank_accounts, through: :saving_bank_accounts
  has_many :goal_savings, dependent: :destroy
  has_many :goals, through: :goal_savings
  has_many :saving_transactions, dependent: :destroy
  has_many :transactions, through: :saving_transactions, source: :transaction_record

  # Nested attributes for handling category and bank account assignments
  accepts_nested_attributes_for :saving_categories, allow_destroy: true
  accepts_nested_attributes_for :saving_bank_accounts, allow_destroy: true

  # Enums
  enum :status, {
    active: "active",
    completed: "completed",
    paused: "paused",
    archived: "archived"
  }, prefix: :status

  # Callbacks to sync status with discarded_at
  after_discard :set_archived_status
  after_undiscard :restore_active_status

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :current_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :color, presence: true

  # Conditional validations
  validate :categories_required_for_auto_sync
  validate :bank_accounts_required_for_auto_sync

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :paused, -> { where(status: "paused") }
  scope :archived, -> { where(status: "archived") }
  scope :with_auto_sync, -> { where(auto_sync_transactions: true) }
  scope :filtered_by_status, ->(status) { where(status: status) }
  scope :filtered_by_goal, ->(goal_id) { joins(:goals).where(goals: { id: goal_id }) }

  # Callbacks
  after_initialize :set_defaults, if: :new_record?

  # Instance Methods

  # Calculate progress percentage
  def progress_percentage
    return 0 if target_amount.zero?

    ((current_amount.to_f / target_amount.to_f) * 100).round(2)
  end

  # Calculate amount remaining to reach target
  def amount_remaining
    target_amount - current_amount
  end

  # Check if saving is on track (simplified version)
  def on_track?
    return true if status_completed?

    progress_percentage >= 0 # For now, any progress is "on track"
  end

  # Action: Mark saving as completed
  def complete_saving!
    update!(
      status: "completed",
      current_amount: target_amount
    )
  end

  # Action: Pause saving
  def pause!
    update!(status: "paused")
  end

  # Action: Resume saving
  def resume!
    update!(status: "active")
  end

  # Action: Archive saving
  def archive!
    update!(status: "archived")
  end

  # Recalculate current_amount from linked transactions
  def recalculate_current_amount!
    total = saving_transactions.sum(:amount_applied)
    update_column(:current_amount, total)
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
    self.color ||= "#3B82F6"
    self.status ||= "active"
    self.current_amount ||= 0
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
    # Restore to active status when unarchiving, unless it was completed
    update_column(:status, "active") unless status_completed?
  end
end

# == Schema Information
#
# Table name: savings
#
# Columns:
#  id                      :integer         not null   no default           no index
#  user_id                 :integer         not null   no default           index: index_savings_on_user_id
#  name                    :string          not null   no default           no index
#  target_amount           :decimal         not null   no default           no index
#  current_amount          :decimal         not null   default: 0.0         no index
#  auto_sync_transactions  :boolean         not null   default: false       no index
#  calculation_settings    :jsonb           not null   default: {}          no index
#  icon                    :string          null       no default           no index
#  color                   :string          null       default: #3B82F6     no index
#  status                  :string          not null   default: active      no index
#  notes                   :text            null       no default           no index
#  discarded_at            :datetime        null       no default           no index
#  created_at              :datetime        not null   no default           no index
#  updated_at              :datetime        not null   no default           no index
#
# Indexes:
#  index_savings_on_user_id       (user_id) non-unique
#
# Associations:
#  categories - through saving_categories junction table
#  bank_accounts - through saving_bank_accounts junction table
#
