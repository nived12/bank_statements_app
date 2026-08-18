module Transactions
  class TransferReconciler < ApplicationService
    include Transactions::Concerns::ConceptSimilarity
    include Transactions::Concerns::TransferLinker

    # How much better the best description match must be than the runner-up before
    # we auto-link rather than ask the user.
    SIMILARITY_ADVANTAGE_THRESHOLD = 0.15

    # Word-overlap alone is a poor floor here: a genuine pair often shares nothing
    # ("TRANSFERENCIA" out, "DEPOSITO" in). What distinguishes a real transfer is
    # that both sides speak transfer language. A card purchase like
    # "MERCADOPAGO ABELARDO" does not, which is what stopped it being auto-linked
    # to an unrelated incoming SPEI. Deliberately excludes the bare word "PAGO",
    # which appears inside merchant names such as MERCADOPAGO.
    TRANSFER_VOCABULARY = /
      TRANSFER | TRASPAS | SPEI | DEPOSITO | ABONO | ENVIADO | RECIBIDO | PORTABILIDAD
    /xi

    # Banks disagree about which date they print — BBVA shows fecha de operación,
    # Santander its own posting date, and they can sit 2-3 days apart for the same
    # SPEI. Pairs outside the same day are proposed for review, never auto-linked.
    MATCH_WINDOW_DAYS = 3

    # Only these can become transfers. Anything else is either already paired
    # (transfer_out/transfer_in) or deliberately outside the totals (excluded).
    RECONCILABLE_TYPES = %w[income fixed_expense variable_expense].freeze

    def initialize(user, date_from: nil, date_to: nil)
      @user = user
      @date_from = date_from
      @date_to = date_to
    end

    def call
      linked_by_key = link_by_tracking_key
      fuzzy = link_by_amount_and_date

      success(
        {
          auto_linked: linked_by_key + fuzzy[:auto_linked],
          candidates_created: fuzzy[:candidates_created]
        }
      )
    end

    private

    # --- Phase 1: exact match on the SPEI tracking key ------------------------
    #
    # Banxico assigns one clave de rastreo per operation and both banks print it,
    # so a shared key is proof the two rows are the same movement. No *date*
    # tolerance is needed or wanted — the two statements routinely disagree by 2-3
    # days, which is the whole reason this path exists. The amounts, however, must
    # match exactly: SPEI commissions are billed as their own statement line rather
    # than netted out of the transfer.
    def link_by_tracking_key
      # Same type filter as phase 2. Without it an `excluded` row carrying a clave
      # gets relinked as a transfer, retyping one half of a self-cancelling pair and
      # orphaning the other — which puts a cancelled purchase back into the expense
      # totals. ExcludedPairMarker runs before this in ImportFinalizer, so those rows
      # are already present by the time we get here.
      keyed = unlinked_scope
        .where(transaction_type: RECONCILABLE_TYPES)
        .where.not(tracking_key: [nil, ""])
        .to_a
      return 0 if keyed.empty?

      keyed.group_by(&:tracking_key).sum do |_key, rows|
        outgoing = rows.select { |t| t.amount.negative? }
        incoming = rows.select { |t| t.amount.positive? }

        # More than one candidate on either side means the key is not identifying a
        # single pair; leave those to review rather than guess.
        next 0 unless outgoing.one? && incoming.one?
        next 0 if outgoing.first.bank_account_id == incoming.first.bank_account_id

        # A rejection outranks even a shared clave. This is not a theoretical guard:
        # rows are keyed long after import, so a pair can be rejected while keyless and
        # then handed the same clave by transfers:backfill_tracking_keys, at which point
        # this phase would link it on the key alone — the user's decision never reaching
        # the phase-2 check that would have honoured it.
        next 0 if rejected_pairs.include?([outgoing.first.id, incoming.first.id])

        # Unequal amounts mean the key is wrong, not that a fee was taken. The
        # backfill can mis-assign one: it maps every amount within an 8-line window
        # to the clave printed there, so a running balance or a neighbouring row can
        # claim it. Production produced exactly that — one clave on a -30,625.23
        # charge and a +7,500 deposit, which this rejects.
        next 0 unless outgoing.first.amount.abs == incoming.first.amount.abs

        link_transfer_pair(outgoing.first, incoming.first)
        1
      end
    end

    # --- Phase 2: amount + date, for rows that carry no key -------------------
    def link_by_amount_and_date
      pairs = scored_pairs
      # Indexed by both sides so the contention check is a lookup rather than a scan
      # of every pair. reconcile_all passes no date window and walks a user's whole
      # history, where the quadratic version would bite.
      rivals = Hash.new { |hash, key| hash[key] = [] }
      pairs.each do |pair|
        rivals[[:out, pair[:outgoing].id]] << pair
        rivals[[:in, pair[:incoming].id]] << pair
      end

      consumed = Set.new
      auto_linked = 0
      candidates_created = 0

      # Best pairs first, so a strong match claims its counterpart before a weak one
      # can. The previous implementation walked outgoing rows in date order and let
      # whichever came first take the only candidate it could see — that is how a
      # MercadoPago card purchase ended up linked to an unrelated incoming SPEI.
      pairs.sort_by { |p| [p[:same_date] ? 0 : 1, -p[:score]] }.each do |pair|
        next if consumed.include?(pair[:outgoing].id) || consumed.include?(pair[:incoming].id)

        if auto_linkable?(pair, rivals, consumed)
          link_transfer_pair(pair[:outgoing], pair[:incoming])
          consumed << pair[:outgoing].id << pair[:incoming].id
          auto_linked += 1
        elsif worth_reviewing?(pair) && create_candidate(pair)
          candidates_created += 1
        end
      end

      { auto_linked: auto_linked, candidates_created: candidates_created }
    end

    def auto_linkable?(pair, rivals, consumed)
      return false unless pair[:same_date]
      return false unless describes_a_transfer?(pair) || pair[:score] >= SIMILARITY_ADVANTAGE_THRESHOLD

      !contested?(pair, rivals, consumed)
    end

    # Same amount on the same day across two accounts is a strong enough coincidence
    # to be worth a look on its own. Spread over three days it is not: the window is
    # three times wider, and it will eventually pair a card purchase with an unrelated
    # deposit. Asking anyway is not free — review fatigue becomes rubber-stamping, and
    # accepting a false pair destroys a real expense and a real income at once. So a
    # multi-day pair has to offer something: both sides speaking transfer language, or
    # at least one word in common.
    def worth_reviewing?(pair)
      pair[:same_date] || describes_a_transfer?(pair) || pair[:score].positive?
    end

    def describes_a_transfer?(pair)
      pair[:outgoing].description.to_s.match?(TRANSFER_VOCABULARY) &&
        pair[:incoming].description.to_s.match?(TRANSFER_VOCABULARY)
    end

    # A pair is contested when either side has another live *same-date* candidate
    # scoring within SIMILARITY_ADVANTAGE_THRESHOLD — nothing tells us which pairing
    # is right, so both go to the user. A next-day alternative does not contest a
    # same-day match; the closer date already decides it.
    def contested?(pair, rivals, consumed)
      candidates = rivals[[:out, pair[:outgoing].id]] + rivals[[:in, pair[:incoming].id]]

      candidates.any? do |other|
        next false if other.equal?(pair)
        next false unless other[:same_date]
        next false if consumed.include?(other[:outgoing].id) || consumed.include?(other[:incoming].id)

        (pair[:score] - other[:score]) < SIMILARITY_ADVANTAGE_THRESHOLD
      end
    end

    def scored_pairs
      incoming_by_amount = incoming_transactions.group_by { |t| t.amount.abs }

      outgoing_transactions.flat_map do |outgoing|
        (incoming_by_amount[outgoing.amount.abs] || []).filter_map do |incoming|
          next if incoming.bank_account_id == outgoing.bank_account_id
          next if (incoming.date - outgoing.date).abs > MATCH_WINDOW_DAYS
          next if rejected_pairs.include?([outgoing.id, incoming.id])

          {
            outgoing: outgoing,
            incoming: incoming,
            same_date: incoming.date == outgoing.date,
            score: calculate_similarity(outgoing.description.to_s, incoming.description.to_s)
          }
        end
      end
    end

    # Pairs the user has already turned down. The reconciler runs again on every import,
    # so without this a rejection lasts only until the next statement lands:
    #
    #   - a same-date rejected pair gets auto-linked outright, overriding the decision;
    #   - and `create_candidate` finds the rejected row and reports it as reviewable,
    #     which put "1 candidato para revisar" on a link whose modal — filtering for
    #     pending — was correctly empty.
    #
    # Dropping them here rather than at either symptom keeps one rule in one place:
    # a rejected pair is not a pair.
    def rejected_pairs
      @rejected_pairs ||= @user.transfer_candidates
        .rejected
        .pluck(:outgoing_transaction_id, :incoming_transaction_id)
        .to_set
    end

    # --- Scopes ---------------------------------------------------------------

    # Archived accounts are excluded: re-uploading a statement that was first imported
    # under an account the user has since archived otherwise pairs the new rows against
    # the old ones and asks them to review transfers between an account and its own
    # replacement.
    def unlinked_scope
      scope = @user.transactions
                   .joins(:bank_account)
                   .merge(BankAccount.kept)
                   .where(source: :statement_file, linked_transfer_id: nil)
      scope = scope.where(date: @date_from..) if @date_from
      scope = scope.where(date: ..@date_to) if @date_to
      scope
    end

    def outgoing_transactions
      unlinked_scope
        .where(transaction_type: %i[fixed_expense variable_expense])
        .where("amount < 0")
        .order(:date)
        .to_a
    end

    def incoming_transactions
      @incoming_transactions ||= unlinked_scope
        .where(transaction_type: :income)
        .where("amount > 0")
        .to_a
    end

    # --- Candidates -----------------------------------------------------------

    # Returns true only when a reviewable candidate was actually persisted. The UI
    # counts TransferCandidate.linkable, so reporting a candidate whose rows are
    # already paired produced the "N candidatos para revisar" link that opened an
    # empty modal.
    #
    # No linked-state re-check here: rows linked by a previous run are excluded at
    # query time by `unlinked_scope`, and rows linked earlier in this run are held in
    # `consumed`, which the caller checks before reaching this point. An earlier
    # version reloaded both sides, which cost two queries per candidate and guarded
    # nothing those two already cover.
    def create_candidate(pair)
      TransferCandidate.create_with(similarity_score: pair[:score]).find_or_create_by!(
        user: @user,
        outgoing_transaction: pair[:outgoing],
        incoming_transaction: pair[:incoming]
      )
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end
end
