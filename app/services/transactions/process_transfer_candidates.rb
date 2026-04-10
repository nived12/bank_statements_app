module Transactions
  class ProcessTransferCandidates < ApplicationService
    include Transactions::Concerns::TransferLinker

    def initialize(user, accepted_ids: [], rejected_ids: [])
      @user = user
      @accepted_ids = accepted_ids
      @rejected_ids = rejected_ids
    end

    def call
      linked_count = 0
      rejected_count = 0

      ActiveRecord::Base.transaction do
        linked_count = process_accepted
        rejected_count = process_rejected
      end

      success({ linked_count: linked_count, rejected_count: rejected_count })
    end

    private

    def process_accepted
      candidates = @user.transfer_candidates.pending.linkable.where(id: @accepted_ids)
      count = 0

      candidates.each do |candidate|
        outgoing = candidate.outgoing_transaction
        incoming = candidate.incoming_transaction

        link_transfer_pair(outgoing, incoming)
        candidate.accepted!
        reject_conflicting_candidates(candidate)
        count += 1
      end

      count
    end

    def reject_conflicting_candidates(linked_candidate)
      @user.transfer_candidates.pending.where(
        outgoing_transaction_id: linked_candidate.outgoing_transaction_id
      ).or(
        @user.transfer_candidates.pending.where(
          incoming_transaction_id: linked_candidate.incoming_transaction_id
        )
      ).update_all(status: "rejected")
    end

    def process_rejected
      @user.transfer_candidates.pending.where(id: @rejected_ids).update_all(status: "rejected")
    end
  end
end
