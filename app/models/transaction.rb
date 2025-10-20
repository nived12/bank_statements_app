# app/models/transaction.rb
class Transaction < ApplicationRecord
  include Filterable
  include Sortable
  include Searchable

  belongs_to :user
  belongs_to :bank_account
  belongs_to :statement_file, optional: true
  belongs_to :category, optional: true
  belongs_to :linked_transfer, class_name: "Transaction", optional: true
  has_one :reverse_transfer, class_name: "Transaction", foreign_key: :linked_transfer_id

  # Goals associations
  has_many :goal_transactions, dependent: :destroy
  has_many :goals, through: :goal_transactions

  enum :transaction_type, {
    income: "income",
    fixed_expense: "fixed_expense",
    variable_expense: "variable_expense",
    transfer_out: "transfer_out",
    transfer_in: "transfer_in"
  }, prefix: :ttype

  enum :bank_entry_type, {
    credit: "credit",
    debit: "debit"
  }, prefix: :btype

  enum :source, {
    manual: 0,
    statement_file: 1
  }

  validates :date, :description, :amount, :transaction_type, presence: true
  validates :amount, numericality: { other_than: 0 }
  validates :description, length: { minimum: 4, message: "must be meaningful (at least 4 characters)" }
  validates :confidence, :category_confidence, :transaction_type_confidence,
            numericality: { in: 0.0..1.0, allow_nil: true }

  # Transfer-specific validations
  validate :transfer_must_have_linked_transfer
  validate :linked_transfer_only_for_transfers

  # Cascade deletion for transfer pairs
  before_destroy :destroy_linked_transfer, if: :transfer?

  # Auto-link to goals on creation and relevant updates
  after_commit :auto_link_to_goals, on: [:create, :update], if: :should_auto_link?

  def transfer_must_have_linked_transfer
    if (ttype_transfer_out? || ttype_transfer_in?) && linked_transfer_id.blank?
      errors.add(:linked_transfer_id, "must be present for transfer transactions")
    end
  end

  def linked_transfer_only_for_transfers
    if linked_transfer_id.present? && !(ttype_transfer_out? || ttype_transfer_in?)
      errors.add(:linked_transfer_id, "can only be set for transfer transactions")
    end
  end

  # Transfer scopes
  scope :transfers, -> { where(transaction_type: [:transfer_out, :transfer_in]) }
  scope :non_transfers, -> { where.not(transaction_type: [:transfer_out, :transfer_in]) }

  # Scope for transactions relevant to balance calculations
  scope :relevant_for_balance, ->(opening_balance_date) {
    where("date >= ?", opening_balance_date)
  }

  scope :historical, ->(opening_balance_date) {
    where("date < ?", opening_balance_date)
  }

  # Date range scopes for filtering
  scope :date_from, ->(date) { where("date >= ?", date) if date.present? }
  scope :date_to, ->(date) { where("date <= ?", date) if date.present? }
  scope :date_range, ->(from_date, to_date) {
    if from_date.present? && to_date.present?
      where(date: from_date..to_date)
    elsif from_date.present?
      date_from(from_date)
    elsif to_date.present?
      date_to(to_date)
    else
      all
    end
  }

  # Filtering scopes for Filterable concern
  scope :filter_by_bank_account_id, ->(bank_account_id) { where(bank_account_id: bank_account_id) }
  scope :filter_by_statement_file_id, ->(statement_file_id) { where(statement_file_id: statement_file_id) }
  scope :filter_by_transaction_type, ->(transaction_type) {
    if transaction_type == "transfer"
      where(transaction_type: [:transfer_out, :transfer_in])
    else
      where(transaction_type: transaction_type)
    end
  }
  scope :filter_by_from_date, ->(from_date) { where("date >= ?", from_date) }
  scope :filter_by_to_date, ->(to_date) { where("date <= ?", to_date) }
  scope :filter_by_date_range, ->(from_date, to_date) { date_range(from_date, to_date) }

  # Sorting scopes for Sortable concern
  scope :sort_by_date, ->(direction) { order(date: direction) }
  scope :sort_by_amount, ->(direction) { order(amount: direction) }
  scope :sort_by_description, ->(direction) { order(description: direction) }
  scope :sort_by_transaction_type, ->(direction) { order(transaction_type: direction) }
  scope :sort_by_merchant, ->(direction) { order(merchant: direction) }
  scope :sort_by_category, ->(direction) {
    # Validate direction to prevent SQL injection
    valid_directions = %w[ASC DESC asc desc]
    direction = valid_directions.include?(direction) ? direction : "ASC"

    left_joins(:category)
      .order(Arel.sql("CASE WHEN categories.name IS NULL THEN 1 ELSE 0 END, categories.name #{direction}"))
  }
  scope :sort_by_bank_account, ->(direction) { joins(bank_account: :bank).order('banks.name': direction) }

  # Search scopes for Searchable concern
  scope :search_by_description, ->(query) { where("description ILIKE ?", "%#{query}%") }

  # Instance methods to check transaction relevance
  def relevant_for_balance?
    return true unless bank_account&.opening_balance_date

    date >= bank_account.opening_balance_date
  end

  def historical?
    !relevant_for_balance?
  end

  # Helper method to get the opening balance date for this transaction's account
  def account_opening_balance_date
    bank_account&.opening_balance_date
  end

  # Transfer helper methods
  def transfer?
    ttype_transfer_out? || ttype_transfer_in?
  end

  def transfer_account
    return nil unless transfer?

    linked_transfer&.bank_account
  end

  # Goal helper methods
  def linked_to_goals?
    goal_transactions.any?
  end

  def total_amount_applied_to_goals
    goal_transactions.sum(:amount_applied)
  end

  private

  # Destroy the linked transfer transaction when destroying a transfer
  # Clear the linked_transfer_id first to avoid circular deletion and foreign key violations
  def destroy_linked_transfer
    return unless linked_transfer && linked_transfer.persisted?

    paired = linked_transfer

    # Clear both linked_transfer_ids to break the circular reference
    # This avoids infinite loops and foreign key constraint violations
    self.update_column(:linked_transfer_id, nil)
    paired.update_column(:linked_transfer_id, nil)

    # Now destroy the paired transaction
    paired.destroy
  end

  def should_auto_link?
    category_id.present? && bank_account_id.present?
  end

  def auto_link_to_goals
    # Clear existing auto-linked goal_transactions if this is an update
    if saved_change_to_category_id? || saved_change_to_bank_account_id? || saved_change_to_date? || saved_change_to_amount?
      goal_transactions.where(manual: false).destroy_all
    end

    # Re-evaluate and link
    Goals::AutoLinkTransactionService.call(self)
  end
end

# == Schema Information
#
# Table name: transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  bank_account_id      :integer         not null   no default           index: index_transactions_on_bank_account_id, index_transactions_on_bank_account_id_and_date
#  statement_file_id    :integer         null       no default           index: index_transactions_on_statement_file_id
#  date                 :date            not null   no default           index: index_transactions_on_bank_account_id_and_date, index_transactions_on_date
#  description          :string          not null   no default           no index
#  amount               :decimal         not null   no default           no index
#  transaction_type     :string          not null   no default           index: index_transactions_on_transaction_type
#  bank_entry_type      :string          null       no default           no index
#  merchant             :string          null       no default           no index
#  reference            :string          null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  user_id              :integer         not null   no default           index: index_transactions_on_user_id
#  category_id          :integer         null       no default           index: index_transactions_on_category_id
#  confidence           :decimal         null       no default           no index
#  category_confidence  :decimal         null       no default           no index
#  transaction_type_confidence :decimal         null       no default           no index
#  source               :integer         not null   default: 0           index: index_transactions_on_source
#  linked_transfer_id   :integer         null       no default           index: index_transactions_on_linked_transfer_id
#
# Indexes:
#  index_transactions_on_bank_account_id (bank_account_id) non-unique
#  index_transactions_on_bank_account_id_and_date (bank_account_id, date) non-unique
#  index_transactions_on_category_id (category_id) non-unique
#  index_transactions_on_date     (date) non-unique
#  index_transactions_on_linked_transfer_id (linked_transfer_id) non-unique
#  index_transactions_on_source   (source) non-unique
#  index_transactions_on_statement_file_id (statement_file_id) non-unique
#  index_transactions_on_transaction_type (transaction_type) non-unique
#  index_transactions_on_user_id  (user_id) non-unique
#
