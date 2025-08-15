# app/models/transaction.rb
class Transaction < ApplicationRecord
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
