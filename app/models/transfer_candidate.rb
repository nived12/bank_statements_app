class TransferCandidate < ApplicationRecord
  belongs_to :user
  belongs_to :outgoing_transaction, class_name: "Transaction"
  belongs_to :incoming_transaction, class_name: "Transaction"

  enum :status, { pending: "pending", accepted: "accepted", rejected: "rejected" }

  scope :linkable, -> {
    joins("INNER JOIN transactions AS ot ON ot.id = transfer_candidates.outgoing_transaction_id")
      .joins("INNER JOIN transactions AS it ON it.id = transfer_candidates.incoming_transaction_id")
      .where("ot.linked_transfer_id IS NULL AND it.linked_transfer_id IS NULL")
  }

  validates :status, presence: true
  validates :outgoing_transaction_id, uniqueness: { scope: :incoming_transaction_id }
end
