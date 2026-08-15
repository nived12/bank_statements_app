# frozen_string_literal: true

json.data do
  json.candidates @candidates do |candidate|
    outgoing = candidate.outgoing_transaction
    incoming = candidate.incoming_transaction

    json.id(candidate.id)
    json.similarity_score(candidate.similarity_score&.to_f)

    # Both sides always carry the same absolute amount — the reconciler pairs on exact
    # equality — so one figure describes the movement.
    json.amount(outgoing.amount.abs.to_f)

    # Computed here rather than in the client. The web modal derives this gap in
    # JavaScript and shipped a hardcoded "1 day apart", which read as a bug the moment the
    # match window widened from ±1 to ±3 days. A number lets each client pluralise it.
    json.days_apart((incoming.date - outgoing.date).to_i.abs)

    json.outgoing { json.partial!("api/v1/shared/transaction", transaction: outgoing) }
    json.incoming { json.partial!("api/v1/shared/transaction", transaction: incoming) }
  end
end

json.meta do
  json.pagination do
    json.partial!("api/v1/shared/pagination", pagy: @pagy)
  end
end
