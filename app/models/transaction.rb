# app/models/transaction.rb
class Transaction < ApplicationRecord
  include Filterable
  include Sortable
  include Searchable

  belongs_to :user
  belongs_to :bank_account
  belongs_to :statement_file
  belongs_to :category, optional: true

  enum :transaction_type, {
    income: "income",
    fixed_expense: "fixed_expense",
    variable_expense: "variable_expense"
  }, prefix: :ttype

  enum :bank_entry_type, {
    credit: "credit",
    debit: "debit"
  }, prefix: :btype

  validates :date, :description, :amount, :transaction_type, presence: true
  validates :amount, numericality: true

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
  scope :filter_by_transaction_type, ->(transaction_type) { where(transaction_type: transaction_type) }
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
end

# == Schema Information
#
# Table name: transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  bank_account_id      :integer         not null   no default           index: index_transactions_on_bank_account_id
#  statement_file_id    :integer         not null   no default           index: index_transactions_on_statement_file_id
#  date                 :date            not null   no default           index: index_transactions_on_date
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
#
# Indexes:
#  index_transactions_on_bank_account_id (bank_account_id) non-unique
#  index_transactions_on_category_id (category_id) non-unique
#  index_transactions_on_date     (date) non-unique
#  index_transactions_on_statement_file_id (statement_file_id) non-unique
#  index_transactions_on_transaction_type (transaction_type) non-unique
#  index_transactions_on_user_id  (user_id) non-unique
#
