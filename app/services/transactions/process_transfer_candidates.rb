module Transactions
  class ProcessTransferCandidates < ApplicationService
    def initialize(user, accepted_ids: [], rejected_ids: [])
      @user = user
      @accepted_ids = accepted_ids
      @rejected_ids = rejected_ids
    end

    def call
      linked_count = 0

      ActiveRecord::Base.transaction do
        linked_count = process_accepted
        process_rejected
      end

      success({ linked_count: linked_count, rejected_count: @rejected_ids.size })
    end

    private

    def process_accepted
      candidates = @user.transfer_candidates.pending.where(id: @accepted_ids)
      count = 0

      candidates.each do |candidate|
        outgoing = candidate.outgoing_transaction
        incoming = candidate.incoming_transaction

        next if outgoing.linked_transfer_id.present? || incoming.linked_transfer_id.present?

        link_pair(outgoing, incoming)
        candidate.accepted!
        count += 1
      end

      count
    end

    def process_rejected
      @user.transfer_candidates.pending.where(id: @rejected_ids).update_all(status: "rejected")
    end

    def link_pair(outgoing, incoming)
      outgoing.transaction_type = "transfer_out"
      incoming.transaction_type = "transfer_in"
      outgoing.save!(validate: false)
      incoming.save!(validate: false)
      outgoing.update_column(:linked_transfer_id, incoming.id)
      incoming.update_column(:linked_transfer_id, outgoing.id)
    end
  end
end
