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

# == Schema Information
#
# Table name: transfer_candidates
#
# Columns:
#  id                   :integer         not null   no default           no index
#  user_id              :integer         not null   no default           index: index_transfer_candidates_on_user_id, index_transfer_candidates_on_user_id_and_status
#  outgoing_transaction_id :integer         not null   no default           index: idx_transfer_candidates_pair, index_transfer_candidates_on_outgoing_transaction_id
#  incoming_transaction_id :integer         not null   no default           index: idx_transfer_candidates_pair, index_transfer_candidates_on_incoming_transaction_id
#  status               :string          not null   default: pending     index: index_transfer_candidates_on_user_id_and_status
#  similarity_score     :decimal         null       no default           no index
#  created_at           :datetime        not null   no default           no index
#  updated_at           :datetime        not null   no default           no index
#
# Indexes:
#  idx_transfer_candidates_pair   (outgoing_transaction_id, incoming_transaction_id) unique
#  index_transfer_candidates_on_incoming_transaction_id (incoming_transaction_id) non-unique
#  index_transfer_candidates_on_outgoing_transaction_id (outgoing_transaction_id) non-unique
#  index_transfer_candidates_on_user_id (user_id) non-unique
#  index_transfer_candidates_on_user_id_and_status (user_id, status) non-unique
#
