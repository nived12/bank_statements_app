# frozen_string_literal: true

class TransactionItem < ApplicationRecord
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id",
    inverse_of: :transaction_items

  validates :name, presence: true, length: { in: 1..120 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }
end
