class Goal < ApplicationRecord
  include Discard::Model

  # Associations
  belongs_to :user
  has_many :goal_savings, dependent: :destroy
  has_many :savings, through: :goal_savings
  has_many :goal_debts, dependent: :destroy
  has_many :debts, through: :goal_debts

  # Enums
  enum :goal_type, {
    savings_goal: "savings_goal",
    debt_payoff: "debt_payoff"
  }, prefix: :type

  enum :debt_strategy, {
    snowball: "snowball",
    avalanche: "avalanche"
  }, prefix: :strategy

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
  validates :goal_type, presence: true
  validates :start_date, presence: true
  validates :deadline, presence: true
  validates :status, presence: true
  validates :color, presence: true

  # Conditional validations
  validate :deadline_after_start_date
  validate :debt_strategy_required_for_debt_payoff

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :paused, -> { where(status: "paused") }
  scope :archived, -> { where(status: "archived") }
  scope :by_deadline, -> { order(deadline: :asc) }
  scope :savings_goals, -> { where(goal_type: "savings_goal") }
  scope :debt_payoff_goals, -> { where(goal_type: "debt_payoff") }

  # Callbacks
  after_initialize :set_defaults, if: :new_record?

  # Instance Methods

  # Aggregated target amount from savings/debts
  def total_target_amount
    if type_savings_goal?
      savings.sum(:target_amount)
    else
      0 # For debt_payoff, target is usually $0
    end
  end

  # Aggregated current amount from savings/debts
  def total_current_amount
    if type_savings_goal?
      savings.sum(:current_amount)
    else
      # For debt_payoff, calculate total amount paid down
      debts.sum { |d| d.amount_paid }
    end
  end

  # Calculate progress percentage
  def progress_percentage
    if type_debt_payoff?
      # For debt payoff, calculate based on amount paid down
      total_debt = debts.sum(:original_amount)
      return 0 if total_debt.zero?

      ((total_current_amount.to_f / total_debt) * 100).round(2)
    else
      # For savings, simple percentage
      return 0 if total_target_amount.zero?

      ((total_current_amount.to_f / total_target_amount.to_f) * 100).round(2)
    end
  end

  # Calculate amount remaining
  def amount_remaining
    if type_debt_payoff?
      # For debt, calculate remaining debt balance
      debts.sum(:current_balance)
    else
      # For savings, calculate remaining to save
      total_target_amount - total_current_amount
    end
  end

  # Calculate days remaining until deadline
  def days_remaining
    (deadline - Date.today).to_i
  end

  # Calculate months remaining until deadline
  def months_remaining
    months = ((deadline.year - Date.today.year) * 12) + (deadline.month - Date.today.month)
    months.positive? ? months : 0
  end

  # Calculate monthly contribution needed to meet goal
  def monthly_contribution_needed
    return 0 if months_remaining.zero? || status_completed?

    remaining = amount_remaining
    return 0 if remaining <= 0

    (remaining / months_remaining.to_f).round(2)
  end

  # Calculate actual monthly contribution rate based on history
  def actual_monthly_contribution
    return 0 if months_since_start.zero?

    (total_current_amount.to_f / months_since_start).round(2)
  end

  # Calculate months since start date
  def months_since_start
    months = ((Date.today.year - start_date.year) * 12) + (Date.today.month - start_date.month)
    months.positive? ? months : 0
  end

  # Check if goal is on track
  def on_track?
    return true if status_completed?
    return false if days_remaining.negative?

    progress = progress_percentage
    time_elapsed_percentage = time_elapsed_percentage()

    # Goal is on track if progress >= expected progress based on time elapsed
    progress >= time_elapsed_percentage
  end

  # Calculate percentage of time elapsed
  def time_elapsed_percentage
    total_days = (deadline - start_date).to_i
    return 100 if total_days.zero?

    days_elapsed = (Date.today - start_date).to_i
    ((days_elapsed.to_f / total_days) * 100).round(2)
  end

  # Calculate projected completion date based on current pace
  def projected_completion_date
    return deadline if status_completed? || actual_monthly_contribution.zero?

    remaining = amount_remaining
    return Date.today if remaining <= 0

    months_needed = (remaining / actual_monthly_contribution).ceil
    Date.today + months_needed.months
  end

  # Status helper: is behind schedule?
  def behind_schedule?
    !on_track? && !status_completed? && days_remaining.positive?
  end

  # Status helper: is past deadline?
  def past_deadline?
    days_remaining.negative? && !status_completed?
  end

  # Status helper: is approaching deadline? (within 30 days)
  def approaching_deadline?
    days_remaining.between?(0, 30) && !status_completed?
  end

  # Action: Mark goal as completed
  def complete_goal!
    update!(status: "completed")
  end

  # Action: Pause goal
  def pause!
    update!(status: "paused")
  end

  # Action: Resume goal
  def resume!
    update!(status: "active")
  end

  # Action: Archive goal
  def archive!
    update!(status: "archived")
  end

  # Prioritize debts based on strategy
  def prioritize_debts
    return debts.active unless debt_strategy.present?

    case debt_strategy
    when "snowball"
      debts.active.order(:current_balance)
    when "avalanche"
      debts.active.order(interest_rate: :desc)
    else
      debts.active
    end
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
    self.goal_calculation_settings ||= {}
  end

  def deadline_after_start_date
    return if deadline.blank? || start_date.blank?

    if deadline <= start_date
      errors.add(:deadline, :after_start_date)
    end
  end

  def debt_strategy_required_for_debt_payoff
    if type_debt_payoff? && debt_strategy.blank?
      errors.add(:debt_strategy, :required_for_debt)
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
# Table name: goals
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_goals_on_user_id, index_goals_on_user_id_and_status
#  name                 :string          not null   no default           no index
#  goal_type            :string          not null   no default           index: index_goals_on_goal_type
#  start_date           :date            not null   no default           no index
#  deadline             :date            not null   no default           index: index_goals_on_deadline
#  debt_strategy        :string          null       no default           no index
#  icon                 :string          null       no default           no index
#  color                :string          not null   default: #3B82F6     no index
#  status               :string          not null   default: active      index: index_goals_on_status, index_goals_on_user_id_and_status
#  notes                :text            null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  discarded_at         :datetime        null       no default           index: index_goals_on_discarded_at
#  goal_calculation_settings :jsonb           not null   default: {}          no index
#
# Indexes:
#  index_goals_on_deadline        (deadline) non-unique
#  index_goals_on_discarded_at    (discarded_at) non-unique
#  index_goals_on_goal_type       (goal_type) non-unique
#  index_goals_on_status          (status) non-unique
#  index_goals_on_user_id         (user_id) non-unique
#  index_goals_on_user_id_and_status (user_id, status) non-unique
#
