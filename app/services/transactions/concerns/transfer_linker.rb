module Transactions
  module Concerns
    module TransferLinker
      private

      # Link an outgoing and incoming transaction as a transfer pair.
      # Both records must already be persisted (IDs exist), so we can set all
      # attributes in memory before the two saves — 2 DB writes instead of 4.
      # save!(validate: false) bypasses the transfer_must_have_linked_transfer
      # validator that would otherwise reject setting the transfer_* type without
      # linked_transfer_id already present.
      def link_transfer_pair(outgoing, incoming)
        ActiveRecord::Base.transaction do
          outgoing.transaction_type = "transfer_out"
          outgoing.linked_transfer_id = incoming.id
          incoming.transaction_type = "transfer_in"
          incoming.linked_transfer_id = outgoing.id
          outgoing.save!(validate: false)
          incoming.save!(validate: false)
        end
      end
    end
  end
end
