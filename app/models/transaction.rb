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
