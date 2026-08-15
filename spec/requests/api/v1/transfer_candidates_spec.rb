# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TransferCandidates", type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { { "Authorization" => "Bearer #{Auth::GenerateTokensService.call(user).payload[:access_token]}" } }
  let(:account_a) { create(:bank_account, user: user) }
  let(:account_b) { create(:bank_account, user: user) }

  def pair(outgoing_date: Date.new(2026, 7, 18), incoming_date: Date.new(2026, 7, 20), amount: 14_000.00)
    outgoing = create(
      :transaction, user: user, bank_account: account_a, amount: -amount, date: outgoing_date,
      transaction_type: "variable_expense", description: "PAGO TRANSFERENCIA SPEI ENVIADO"
    )
    incoming = create(
      :transaction, user: user, bank_account: account_b, amount: amount, date: incoming_date,
      transaction_type: "income", description: "SPEI RECIBIDO SANTANDER"
    )
    create(:transfer_candidate, user: user, outgoing_transaction: outgoing, incoming_transaction: incoming)
  end

  describe "GET /api/v1/transfer_candidates" do
    it "returns pending candidates with both sides of the pair" do
      candidate = pair

      get "/api/v1/transfer_candidates", headers: auth_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["candidates"].size).to eq(1)

      returned = body["data"]["candidates"].first
      expect(returned["id"]).to eq(candidate.id)
      expect(returned["amount"]).to eq(14_000.0)
      expect(returned["outgoing"]["amount"]).to eq(-14_000.0)
      expect(returned["incoming"]["amount"]).to eq(14_000.0)
      expect(returned["outgoing"]["bank_account"]["name"]).to be_present
    end

    # Mobile formats this through i18next pluralisation. The web UI computes the gap in
    # JavaScript and shipped a hardcoded "1 day apart", which read as a bug once the match
    # window widened from ±1 to ±3 days — sending a number avoids repeating that.
    it "reports how many days apart the two sides are" do
      pair(outgoing_date: Date.new(2026, 7, 18), incoming_date: Date.new(2026, 7, 20))

      get "/api/v1/transfer_candidates", headers: auth_headers

      expect(JSON.parse(response.body)["data"]["candidates"].first["days_apart"]).to eq(2)
    end

    it "omits candidates whose transactions are already linked" do
      candidate = pair
      # A linked row is always typed as a transfer — the model rejects a linked_transfer_id
      # without it — so set both, the way TransferLinker leaves them.
      candidate.outgoing_transaction.update!(
        transaction_type: "transfer_out", linked_transfer_id: candidate.incoming_transaction_id
      )

      get "/api/v1/transfer_candidates", headers: auth_headers

      expect(JSON.parse(response.body)["data"]["candidates"]).to be_empty
    end

    it "omits candidates that are not pending" do
      pair.rejected!

      get "/api/v1/transfer_candidates", headers: auth_headers

      expect(JSON.parse(response.body)["data"]["candidates"]).to be_empty
    end

    it "never returns another user's candidates" do
      other = create(:user)
      other_account = create(:bank_account, user: other)
      outgoing = create(:transaction, user: other, bank_account: other_account, amount: -500)
      incoming = create(:transaction, :income, user: other, bank_account: create(:bank_account, user: other))
      create(:transfer_candidate, user: other, outgoing_transaction: outgoing, incoming_transaction: incoming)

      get "/api/v1/transfer_candidates", headers: auth_headers

      expect(JSON.parse(response.body)["data"]["candidates"]).to be_empty
    end

    it "requires authentication" do
      get "/api/v1/transfer_candidates"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/transfer_candidates/resolve" do
    it "links an accepted pair" do
      candidate = pair

      post "/api/v1/transfer_candidates/resolve",
        params: { accepted_ids: [candidate.id] }.to_json,
        headers: auth_headers.merge("CONTENT_TYPE" => "application/json")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["linked_count"]).to eq(1)

      expect(candidate.reload.status).to eq("accepted")
      expect(candidate.outgoing_transaction.reload.transaction_type).to eq("transfer_out")
      expect(candidate.incoming_transaction.reload.transaction_type).to eq("transfer_in")
      expect(candidate.outgoing_transaction.linked_transfer_id).to eq(candidate.incoming_transaction_id)
    end

    it "rejects a dismissed pair without touching its transactions" do
      candidate = pair

      post "/api/v1/transfer_candidates/resolve",
        params: { rejected_ids: [candidate.id] }.to_json,
        headers: auth_headers.merge("CONTENT_TYPE" => "application/json")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["rejected_count"]).to eq(1)
      expect(candidate.reload.status).to eq("rejected")
      expect(candidate.outgoing_transaction.reload.transaction_type).to eq("variable_expense")
      expect(candidate.outgoing_transaction.linked_transfer_id).to be_nil
    end

    # The reconciler runs again on every import. A rejection that only held until the next
    # statement landed would be worthless — this is the guard added in #311, asserted from
    # the API surface the mobile app actually calls.
    it "does not re-offer a pair the user dismissed" do
      candidate = pair

      post "/api/v1/transfer_candidates/resolve",
        params: { rejected_ids: [candidate.id] }.to_json,
        headers: auth_headers.merge("CONTENT_TYPE" => "application/json")
      Transactions::TransferReconciler.call(user)

      get "/api/v1/transfer_candidates", headers: auth_headers

      expect(JSON.parse(response.body)["data"]["candidates"]).to be_empty
      expect(candidate.outgoing_transaction.reload.transaction_type).to eq("variable_expense")
    end

    it "accepts and rejects in one call" do
      accepted = pair
      dismissed = pair(outgoing_date: Date.new(2026, 6, 1), incoming_date: Date.new(2026, 6, 2), amount: 900.00)

      post "/api/v1/transfer_candidates/resolve",
        params: { accepted_ids: [accepted.id], rejected_ids: [dismissed.id] }.to_json,
        headers: auth_headers.merge("CONTENT_TYPE" => "application/json")

      expect(accepted.reload.status).to eq("accepted")
      expect(dismissed.reload.status).to eq("rejected")
    end

    it "ignores another user's candidate ids" do
      other = create(:user)
      outgoing = create(:transaction, user: other, bank_account: create(:bank_account, user: other), amount: -500)
      incoming = create(:transaction, :income, user: other, bank_account: create(:bank_account, user: other))
      foreign = create(:transfer_candidate, user: other, outgoing_transaction: outgoing, incoming_transaction: incoming)

      post "/api/v1/transfer_candidates/resolve",
        params: { accepted_ids: [foreign.id] }.to_json,
        headers: auth_headers.merge("CONTENT_TYPE" => "application/json")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["linked_count"]).to eq(0)
      expect(foreign.reload.status).to eq("pending")
    end

    it "succeeds with nothing to do when both id lists are empty" do
      post "/api/v1/transfer_candidates/resolve",
        params: {}.to_json,
        headers: auth_headers.merge("CONTENT_TYPE" => "application/json")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]).to include("linked_count" => 0, "rejected_count" => 0)
    end

    it "requires authentication" do
      post "/api/v1/transfer_candidates/resolve"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
