# frozen_string_literal: true

module Api
  module V1
    ##
    # Api::V1::TransferCandidatesController
    #
    # Transfer pairs the reconciler found but would not link on its own — different dates,
    # tied scores, or descriptions that never say "transfer". Auto-linking already happens
    # on import for both web and API uploads; what mobile lacked was any way to *review*
    # what was left over, so those pairs accumulated with no way to act on them.
    #
    # Both actions delegate to the services the web controller uses, so the two surfaces
    # cannot drift apart.
    #
    class TransferCandidatesController < BaseController
      # GET /api/v1/transfer_candidates
      def index
        @candidates = current_user.transfer_candidates
          .pending
          .linkable
          .includes(
            outgoing_transaction: [:category, :transaction_items, { bank_account: :bank }],
            incoming_transaction: [:category, :transaction_items, { bank_account: :bank }]
          )
          .order(created_at: :desc)
      end

      # POST /api/v1/transfer_candidates/resolve
      #
      # Accepts both lists in one call because the mobile screen batches decisions locally
      # and submits them together — nothing is written until the user saves, so a mis-swipe
      # costs nothing. Unknown or foreign ids are ignored rather than rejected: the service
      # scopes every lookup to the current user, and a stale id from a screen opened before
      # someone reviewed on web is expected, not an error.
      def resolve
        result = Transactions::ProcessTransferCandidates.call(
          current_user,
          accepted_ids: params[:accepted_ids] || [],
          rejected_ids: params[:rejected_ids] || []
        )

        if result.success?
          @linked_count = result.payload[:linked_count]
          @rejected_count = result.payload[:rejected_count]
          render(:resolve, status: :ok)
        else
          render_error(
            "TRANSFER_CANDIDATES_RESOLVE_FAILED",
            message: "Failed to resolve transfer candidates",
            status: :unprocessable_content,
            details: result.errors.full_messages
          )
        end
      end
    end
  end
end
