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
    # so a shared key is proof the two rows are the same movement. No date or
    # amount tolerance is needed or wanted — fees change the amount and the two
    # statements routinely disagree about the date.
    def link_by_tracking_key
      keyed = unlinked_scope.where.not(tracking_key: [nil, ""]).to_a
      return 0 if keyed.empty?

      keyed.group_by(&:tracking_key).sum do |_key, rows|
        outgoing = rows.select { |t| t.amount.negative? }
        incoming = rows.select { |t| t.amount.positive? }

        # More than one candidate on either side means the key is not identifying a
        # single pair; leave those to review rather than guess.
        next 0 unless outgoing.one? && incoming.one?
        next 0 if outgoing.first.bank_account_id == incoming.first.bank_account_id

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
        elsif create_candidate(pair)
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

          {
            outgoing: outgoing,
            incoming: incoming,
            same_date: incoming.date == outgoing.date,
            score: calculate_similarity(outgoing.description.to_s, incoming.description.to_s)
          }
        end
      end
    end

    # --- Scopes ---------------------------------------------------------------

    def unlinked_scope
      scope = @user.transactions.where(source: :statement_file, linked_transfer_id: nil)
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
