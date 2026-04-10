module Transactions
  class TransferReconciler < ApplicationService
    include Transactions::Concerns::ConceptSimilarity
    include Transactions::Concerns::TransferLinker

    SIMILARITY_ADVANTAGE_THRESHOLD = 0.15

    def initialize(user, date_from: nil, date_to: nil)
      @user = user
      @date_from = date_from
      @date_to = date_to
    end

    def call
      auto_linked = 0
      candidates_created = 0
      matched_incoming_ids = Set.new

      outgoing_transactions.each do |outgoing|
        matches = find_matches(outgoing, matched_incoming_ids)
        next if matches.empty?

        result = process_matches(outgoing, matches)

        case result[:action]
        when :auto_linked
          matched_incoming_ids.add(result[:incoming_id])
          auto_linked += 1
        when :candidates_created
          candidates_created += result[:count]
        end
      end

      success({ auto_linked: auto_linked, candidates_created: candidates_created })
    end

    private

    def outgoing_transactions
      scope = @user.transactions
        .where(source: :statement_file, linked_transfer_id: nil)
        .where(transaction_type: %i[fixed_expense variable_expense])
        .where("amount < 0")
      scope = scope.where(date: @date_from..) if @date_from
      scope = scope.where(date: ..@date_to) if @date_to
      scope.order(:date)
    end

    def incoming_transactions
      # Memoized for the lifetime of the call to enable O(n) hash-lookup matching.
      # After an incoming transaction is auto-linked, it remains in this array but is
      # excluded from matching via the matched_incoming_ids Set — intentional trade-off
      # to avoid re-querying the DB on every match.
      @incoming_transactions ||= begin
        scope = @user.transactions
          .where(source: :statement_file, linked_transfer_id: nil)
          .where(transaction_type: :income)
          .where("amount > 0")
        scope = scope.where(date: @date_from..) if @date_from
        scope = scope.where(date: ..@date_to) if @date_to
        scope.to_a
      end
    end

    def incoming_by_amount
      @incoming_by_amount ||= incoming_transactions.group_by { |t| t.amount.abs }
    end

    def find_matches(outgoing, matched_incoming_ids)
      candidates = incoming_by_amount[outgoing.amount.abs] || []

      candidates.select do |incoming|
        !matched_incoming_ids.include?(incoming.id) &&
          incoming.bank_account_id != outgoing.bank_account_id &&
          (incoming.date - outgoing.date).abs <= 1
      end
    end

    def process_matches(outgoing, matches)
      if matches.size == 1
        incoming = matches.first
        if outgoing.date == incoming.date
          link_transfer_pair(outgoing, incoming)
          { action: :auto_linked, incoming_id: incoming.id }
        else
          create_candidate(outgoing, incoming)
          { action: :candidates_created, count: 1 }
        end
      else
        resolve_multiple_matches(outgoing, matches)
      end
    end

    def resolve_multiple_matches(outgoing, matches)
      same_date_matches = matches.select { |m| m.date == outgoing.date }
      effective_matches = same_date_matches.any? ? same_date_matches : matches

      if effective_matches.size == 1 && same_date_matches.any?
        link_transfer_pair(outgoing, effective_matches.first)
        return { action: :auto_linked, incoming_id: effective_matches.first.id }
      end

      scored = effective_matches.map do |incoming|
        score = calculate_similarity(outgoing.description.to_s, incoming.description.to_s)
        { incoming: incoming, score: score }
      end.sort_by { |s| -s[:score] }

      best = scored.first
      second = scored.second

      if best && second &&
          (best[:score] - second[:score]) >= SIMILARITY_ADVANTAGE_THRESHOLD &&
          same_date_matches.include?(best[:incoming])
        link_transfer_pair(outgoing, best[:incoming])
        { action: :auto_linked, incoming_id: best[:incoming].id }
      else
        count = 0
        scored.each do |s|
          create_candidate(outgoing, s[:incoming], similarity_score: s[:score])
          count += 1
        end
        { action: :candidates_created, count: count }
      end
    end

    def create_candidate(outgoing, incoming, similarity_score: nil)
      score = similarity_score || calculate_similarity(
        outgoing.description.to_s, incoming.description.to_s
      )

      TransferCandidate.find_or_create_by!(
        user: @user,
        outgoing_transaction: outgoing,
        incoming_transaction: incoming
      ) do |candidate|
        candidate.similarity_score = score
      end
    rescue ActiveRecord::RecordNotUnique
      # Already exists — safe to ignore
    end
  end
end
