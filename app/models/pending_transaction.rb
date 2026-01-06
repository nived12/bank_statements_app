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

# == Schema Information
#
# Table name: pending_transactions
#
# Columns:
#  id                   :integer         not null   no default           no index
#  statement_file_id    :integer         not null   no default           index: index_pending_transactions_on_statement_file_id
#  user_id              :integer         not null   no default           index: index_pending_transactions_on_user_id
#  bank_account_id      :integer         not null   no default           index: index_pending_transactions_on_bank_account_id
#  description          :text            null       no default           no index
#  amount               :decimal         null       no default           no index
#  transaction_type     :string          null       no default           no index
#  merchant             :string          null       no default           no index
#  reference            :string          null       no default           no index
#  category_id          :integer         null       no default           no index
#  confidence           :decimal         null       no default           no index
#  category_confidence  :decimal         null       no default           no index
#  transaction_type_confidence :decimal         null       no default           no index
#  source               :integer         not null   default: 0           index: index_pending_transactions_on_source
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#  date                 :date            null       no default           no index
#
# Indexes:
#  index_pending_transactions_on_bank_account_id (bank_account_id) non-unique
#  index_pending_transactions_on_source (source) non-unique
#  index_pending_transactions_on_statement_file_id (statement_file_id) non-unique
#  index_pending_transactions_on_user_id (user_id) non-unique
#
