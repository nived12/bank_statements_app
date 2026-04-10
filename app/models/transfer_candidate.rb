class TransferCandidate < ApplicationRecord
  belongs_to :user
  belongs_to :outgoing_transaction, class_name: "Transaction"
  belongs_to :incoming_transaction, class_name: "Transaction"

  enum :status, { pending: "pending", accepted: "accepted", rejected: "rejected" }

  scope :for_user, ->(user) { where(user: user) }

  validates :status, presence: true
  validates :outgoing_transaction_id, uniqueness: { scope: :incoming_transaction_id }
end
