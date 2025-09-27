class PendingTransaction < ApplicationRecord
  belongs_to :statement_file
  belongs_to :user
  belongs_to :bank_account
  belongs_to :category, optional: true

  enum :source, {
    manual: 0,
    statement_file: 1
  }

  validates :date, :description, :amount, :transaction_type, presence: true
  validates :amount, numericality: { other_than: 0 }
  validates :description, length: { minimum: 4, message: "must be meaningful (at least 4 characters)" }
  validates :confidence, :category_confidence, :transaction_type_confidence,
            numericality: { in: 0.0..1.0, allow_nil: true }

  # Scope to find duplicates based on user, bank_account, date, amount
  scope :duplicates_for, ->(user_id, bank_account_id, date, amount) {
    where(user_id: user_id, bank_account_id: bank_account_id, date: date, amount: amount)
  }

  # Scope to find by statement file
  scope :by_statement_file, ->(statement_file_id) {
    where(statement_file_id: statement_file_id)
  }

  # Scope to find by source
  scope :by_source, ->(source) {
    where(source: source)
  }
end
