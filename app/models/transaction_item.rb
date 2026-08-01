# frozen_string_literal: true

class TransactionItem < ApplicationRecord
  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id",
    inverse_of: :transaction_items

  validates :name, presence: true, length: { in: 1..120 }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }
end

# == Schema Information
#
# Table name: transaction_items
#
# Columns:
#  id                   :integer         not null   no default           no index
#  transaction_id       :integer         not null   no default           index: index_transaction_items_on_transaction_id, index_transaction_items_on_transaction_id_and_position
#  name                 :string          not null   no default           no index
#  amount               :decimal         not null   no default           no index
#  position             :integer         not null   default: 0           index: index_transaction_items_on_transaction_id_and_position
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  index_transaction_items_on_transaction_id (transaction_id) non-unique
#  index_transaction_items_on_transaction_id_and_position (transaction_id, position) non-unique
#
