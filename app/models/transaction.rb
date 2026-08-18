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
  belongs_to :recurring_series, optional: true
  # nullify, not destroy: when one side of a pair goes, the other side's money is still
  # real, it is simply no longer half of a transfer. Without this the database FK blocks
  # the delete outright.
  has_one :reverse_transfer, class_name: "Transaction", foreign_key: :linked_transfer_id,
    dependent: :nullify, inverse_of: :linked_transfer

  # Both directions, because a candidate points at two rows and destroying either one
  # leaves the FK dangling. A candidate for a transaction that no longer exists has
  # nothing left to review.
  has_many :outgoing_transfer_candidates, class_name: "TransferCandidate",
    foreign_key: :outgoing_transaction_id, dependent: :destroy,
    inverse_of: :outgoing_transaction
  has_many :incoming_transfer_candidates, class_name: "TransferCandidate",
    foreign_key: :incoming_transaction_id, dependent: :destroy,
    inverse_of: :incoming_transaction

  # Savings and Debts associations
  has_many :saving_transactions, dependent: :destroy
  has_many :savings, through: :saving_transactions
  has_many :debt_transactions, dependent: :destroy
  has_many :debts, through: :debt_transactions

  has_many :transaction_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :transaction_record
  accepts_nested_attributes_for :transaction_items, allow_destroy: true, reject_if: :all_blank

  # `excluded` marks both halves of a pair that undoes itself on a credit card
  # statement: a charge and the credit that reverses it, because the purchase was
  # re-billed as meses sin intereses, refunded, or paid with points. The rows stay
  # visible so the ledger still mirrors the statement, but neither counts as income
  # or spending — the re-billed installments are charged separately and those are
  # what the user actually owes.
  #
  # Nothing extra is needed to keep these out of the totals: every stats site filters
  # *for* income/fixed_expense/variable_expense rather than filtering transfers out,
  # so an unknown type is excluded by construction. Keep it that way.
  # `investment` is value moving between a brokerage's own cash and its own assets. Out
  # of the totals but still in the balance, and unlike `excluded` it stays editable.
  enum :transaction_type, {
    income: "income",
    fixed_expense: "fixed_expense",
    variable_expense: "variable_expense",
    transfer_out: "transfer_out",
    transfer_in: "transfer_in",
    excluded: "excluded",
    investment: "investment"
  }, prefix: :ttype

  enum :source, {
    manual: 0,
    statement_file: 1
  }

  validates :date, :description, :amount, :transaction_type, presence: true
  validates :amount, numericality: { other_than: 0 }
  validates :description, length: { minimum: 4, message: "must be meaningful (at least 4 characters)" }
  validates :confidence, :category_confidence, :transaction_type_confidence,
    numericality: { in: 0.0..1.0, allow_nil: true }
  validates :tax_amount, :tip_amount,
    numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Transfer-specific validations
  validate :transfer_must_have_linked_transfer
  validate :linked_transfer_only_for_transfers
  validate :validate_date_format

  # Normalize amount to 2 decimals before validation
  before_validation :normalize_amount
  before_validation :default_concept_from_description

  # Cascade deletion for transfer pairs
  before_destroy :destroy_linked_transfer, if: :transfer?

  # Auto-link to savings and debts on creation and relevant updates
  after_commit :auto_link_to_savings_and_debts, on: [:create, :update], if: :should_auto_link?

  def transfer_must_have_linked_transfer
    if (ttype_transfer_out? || ttype_transfer_in?) && linked_transfer_id.blank?
      errors.add(:linked_transfer_id, I18n.t("transactions.errors.linked_transfer_required"))
    end
  end

  def linked_transfer_only_for_transfers
    if linked_transfer_id.present? && !(ttype_transfer_out? || ttype_transfer_in?)
      errors.add(:linked_transfer_id, I18n.t("transactions.errors.linked_transfer_only_for_transfers"))
    end
  end

  # Transfer scopes
  scope :transfers, -> { where(transaction_type: [:transfer_out, :transfer_in]) }

  # Transactions that move the balance on from its anchor point.
  #
  # `opening_balance` is the figure at the END of `opening_balance_date` — what the
  # bank app showed the day the user typed it in — so that day's activity is already
  # inside it. Applying it again double-counts: a Santander account anchored the day
  # after a -1,000 transfer read -552.77 against a real closing balance of 447.23.
  scope :relevant_for_balance, ->(opening_balance_date) {
    where("transactions.date > ?", opening_balance_date)
  }

  scope :historical, ->(opening_balance_date) {
    where("transactions.date <= ?", opening_balance_date)
  }

  # Date range scopes for filtering
  scope :date_from, ->(date) { where("transactions.date >= ?", date) if date.present? }
  scope :date_to, ->(date) { where("transactions.date <= ?", date) if date.present? }
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
  scope :filter_by_category_ids, ->(category_ids) {
    ids = Array(category_ids).map(&:to_i).reject(&:zero?)
    return all if ids.empty?

    where(category_id: ids + Category.where(parent_id: ids).select(:id))
  }
  scope :filter_by_transaction_type, ->(transaction_type) {
    if transaction_type == "transfer"
      where(transaction_type: [:transfer_out, :transfer_in])
    else
      where(transaction_type: transaction_type)
    end
  }
  scope :filter_by_from_date, ->(from_date) { where("transactions.date >= ?", from_date) }
  scope :filter_by_to_date, ->(to_date) { where("transactions.date <= ?", to_date) }
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
  scope :search_by_description, ->(query) {
    where("transactions.description ILIKE ? OR transactions.concept ILIKE ?", "%#{query}%", "%#{query}%")
  }

  # Returns a hash of { category_name => count } for the top N categories
  def self.top_category_counts(limit: 3)
    no_category_label = I18n.t("transactions.no_category")
    sanitized_label = connection.quote(no_category_label)
    counts = reorder("")
      .left_joins(:category)
      .group(Arel.sql("COALESCE(categories.name, #{sanitized_label})"))
      .count
    counts.sort_by { |_, c| -c }.first(limit).to_h
  end

  # Instance methods to check transaction relevance
  def relevant_for_balance?
    return true unless bank_account&.opening_balance_date

    date > bank_account.opening_balance_date
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
    return unless transfer?

    linked_transfer&.bank_account
  end


  private

  def normalize_amount
    return unless amount.present?

    # Round to 2 decimal places
    self.amount = amount.to_d.round(2)
  end

  def default_concept_from_description
    self.concept = description if concept.blank? && description.present?
  end

  def validate_date_format
    return unless date.present?

    # Rails automatically converts valid date strings to Date objects
    # If date is not a Date object and can't be parsed, add error
    unless date.is_a?(Date)
      begin
        Date.parse(date.to_s)
      rescue ArgumentError, TypeError
        errors.add(:date, I18n.t("transactions.errors.invalid_date"))
      end
    end
  end

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

  def auto_link_to_savings_and_debts
    # Clear existing auto-linked saving_transactions and debt_transactions if this is an update
    if saved_change_to_category_id? || saved_change_to_bank_account_id? ||
       saved_change_to_date? || saved_change_to_amount?
      saving_transactions.where(manual: false).destroy_all
      debt_transactions.where(manual: false).destroy_all
    end

    # Re-evaluate and link to savings and debts
    Savings::TransactionAutoLinker.call(self)
    Debts::TransactionAutoLinker.call(self)
  end
end

# == Schema Information
#
# Table name: transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  bank_account_id      :integer         not null   no default           index: index_transactions_on_bank_account_id, index_transactions_on_user_id_and_bank_account_id_and_date
#  statement_file_id    :integer         null       no default           index: index_transactions_on_statement_file_id
#  description          :string          not null   no default           no index
#  amount               :decimal         not null   no default           no index
#  transaction_type     :string          not null   no default           index: index_transactions_on_transaction_type
#  merchant             :string          null       no default           no index
#  reference            :string          null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  user_id              :integer         not null   no default           index: index_transactions_on_user_id, index_transactions_on_user_id_and_bank_account_id_and_date, index_transactions_on_user_id_and_date
#  category_id          :integer         null       no default           index: index_transactions_on_category_id
#  confidence           :decimal         null       no default           no index
#  category_confidence  :decimal         null       no default           no index
#  transaction_type_confidence :decimal         null       no default           no index
#  source               :integer         not null   default: 0           index: index_transactions_on_source
#  linked_transfer_id   :integer         null       no default           index: index_transactions_on_linked_transfer_id
#  date                 :date            null       no default           index: index_transactions_on_user_id_and_bank_account_id_and_date, index_transactions_on_user_id_and_date
#  concept              :string          null       no default           index: index_transactions_on_concept
#  recurring_series_id  :integer         null       no default           index: index_transactions_on_recurring_series_id
#  tax_amount           :decimal         null       no default           no index
#  tip_amount           :decimal         null       no default           no index
#
# Indexes:
#  index_transactions_on_bank_account_id (bank_account_id) non-unique
#  index_transactions_on_category_id (category_id) non-unique
#  index_transactions_on_concept  (concept) non-unique
#  index_transactions_on_linked_transfer_id (linked_transfer_id) non-unique
#  index_transactions_on_recurring_series_id (recurring_series_id) non-unique
#  index_transactions_on_source   (source) non-unique
#  index_transactions_on_statement_file_id (statement_file_id) non-unique
#  index_transactions_on_transaction_type (transaction_type) non-unique
#  index_transactions_on_user_id  (user_id) non-unique
#  index_transactions_on_user_id_and_bank_account_id_and_date (user_id, bank_account_id, date) non-unique
#  index_transactions_on_user_id_and_date (user_id, date) non-unique
#
