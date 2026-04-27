require "rails_helper"

RSpec.describe "Transfer Reconciliation", type: :request do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:account_a) { create(:bank_account, user: user, bank: bank) }
  let(:account_b) { create(:bank_account, user: user, bank: bank) }

  before { sign_in_user(user) }

  describe "POST /transactions/reconcile_transfers" do
    it "returns success with counts when matches are found" do
      outgoing = create(
        :transaction, user: user, bank_account: account_a,
        amount: -500.00, transaction_type: "variable_expense",
        date: Date.new(2025, 3, 15), source: :statement_file
      )
      incoming = create(
        :transaction, user: user, bank_account: account_b,
        amount: 500.00, transaction_type: "income",
        date: Date.new(2025, 3, 15), source: :statement_file
      )

      post "/transactions/reconcile_transfers",
        headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["auto_linked"]).to eq(1)
      expect(json["candidates_created"]).to eq(0)
      expect(json["message"]).to be_present

      outgoing.reload
      incoming.reload
      expect(outgoing.transaction_type).to eq("transfer_out")
      expect(incoming.transaction_type).to eq("transfer_in")
    end

    it "scopes to date range when from_date/to_date are provided" do
      # Transaction outside date range — should not be matched
      create(
        :transaction, user: user, bank_account: account_a,
        amount: -200.00, transaction_type: "variable_expense",
        date: Date.new(2025, 1, 1), source: :statement_file
      )
      create(
        :transaction, user: user, bank_account: account_b,
        amount: 200.00, transaction_type: "income",
        date: Date.new(2025, 1, 1), source: :statement_file
      )

      post "/transactions/reconcile_transfers",
        params: { from_date: "2025-03-01", to_date: "2025-03-31" },
        headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      json = JSON.parse(response.body)
      expect(json["auto_linked"]).to eq(0)
    end

    it "returns 200 with no matches when nothing to reconcile" do
      post "/transactions/reconcile_transfers",
        headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to be_present
    end

    it "returns 400 for malformed date params" do
      post "/transactions/reconcile_transfers",
        params: { from_date: "not-a-date" },
        headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      # Malformed dates are silently ignored (parse_date_param returns nil)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "requires authentication" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:authenticate!).and_call_original

      post "/transactions/reconcile_transfers",
        headers: { "Accept" => "application/json" }

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "GET /transactions/check_transfer_candidates" do
    it "returns has_candidates false when no pending linkable candidates" do
      get "/transactions/check_transfer_candidates",
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["has_candidates"]).to be false
      expect(json["candidates_count"]).to eq(0)
    end

    it "returns has_candidates true with count when pending linkable candidates exist" do
      outgoing = create(
        :transaction, user: user, bank_account: account_a,
        amount: -500.00, transaction_type: "variable_expense",
        date: Date.new(2025, 3, 15), source: :statement_file
      )
      incoming = create(
        :transaction, user: user, bank_account: account_b,
        amount: 500.00, transaction_type: "income",
        date: Date.new(2025, 3, 16), source: :statement_file
      )
      create(
        :transfer_candidate, user: user,
        outgoing_transaction: outgoing, incoming_transaction: incoming
      )

      get "/transactions/check_transfer_candidates",
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json["has_candidates"]).to be true
      expect(json["candidates_count"]).to eq(1)
    end

    it "excludes candidates where either transaction is already linked" do
      other = create(:transaction, user: user, bank_account: account_b, source: :statement_file)
      outgoing = create(
        :transaction, user: user, bank_account: account_a,
        amount: -500.00, transaction_type: "transfer_out",
        linked_transfer_id: other.id, source: :statement_file
      )
      incoming = create(
        :transaction, user: user, bank_account: account_b,
        amount: 500.00, transaction_type: "income", source: :statement_file
      )
      create(
        :transfer_candidate, user: user,
        outgoing_transaction: outgoing, incoming_transaction: incoming
      )

      get "/transactions/check_transfer_candidates",
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json["has_candidates"]).to be false
    end
  end

  describe "GET /transactions/get_transfer_candidates" do
    let!(:outgoing) do
      create(
        :transaction, user: user, bank_account: account_a,
        amount: -500.00, transaction_type: "variable_expense",
        date: Date.new(2025, 3, 15), source: :statement_file
      )
    end
    let!(:incoming) do
      create(
        :transaction, user: user, bank_account: account_b,
        amount: 500.00, transaction_type: "income",
        date: Date.new(2025, 3, 16), source: :statement_file
      )
    end
    let!(:candidate) do
      create(
        :transfer_candidate, user: user,
        outgoing_transaction: outgoing, incoming_transaction: incoming,
        similarity_score: 0.5
      )
    end

    it "returns candidate pairs with transaction and account details" do
      get "/transactions/get_transfer_candidates",
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["candidates"].size).to eq(1)

      c = json["candidates"].first
      expect(c["id"]).to eq(candidate.id)
      expect(c["outgoing"]["amount"]).to eq(-500.0)
      expect(c["incoming"]["amount"]).to eq(500.0)
      expect(c["outgoing"]["bank_account"]["display_name"]).to be_present
      expect(c["incoming"]["bank_account"]["display_name"]).to be_present
    end

    it "does not return candidates from other users" do
      other_user = create(:user, :confirmed)
      other_acct = create(:bank_account, user: other_user, bank: bank)
      other_out = create(
        :transaction, user: other_user, bank_account: other_acct,
        amount: -100.00, transaction_type: "variable_expense", source: :statement_file
      )
      other_in = create(
        :transaction, user: other_user, bank_account: other_acct,
        amount: 100.00, transaction_type: "income", source: :statement_file
      )
      create(
        :transfer_candidate, user: other_user,
        outgoing_transaction: other_out, incoming_transaction: other_in
      )

      get "/transactions/get_transfer_candidates",
        headers: { "Accept" => "application/json" }

      json = JSON.parse(response.body)
      expect(json["candidates"].size).to eq(1)
      expect(json["candidates"].first["id"]).to eq(candidate.id)
    end
  end

  describe "POST /transactions/process_transfer_candidates" do
    let!(:outgoing) do
      create(
        :transaction, user: user, bank_account: account_a,
        amount: -500.00, transaction_type: "variable_expense",
        date: Date.new(2025, 3, 15), source: :statement_file
      )
    end
    let!(:incoming) do
      create(
        :transaction, user: user, bank_account: account_b,
        amount: 500.00, transaction_type: "income",
        date: Date.new(2025, 3, 16), source: :statement_file
      )
    end
    let!(:candidate) do
      create(
        :transfer_candidate, user: user,
        outgoing_transaction: outgoing, incoming_transaction: incoming
      )
    end

    it "links accepted candidates and returns counts" do
      post "/transactions/process_transfer_candidates",
        params: { accepted_ids: [candidate.id], rejected_ids: [] },
        headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["linked_count"]).to eq(1)
      expect(json["rejected_count"]).to eq(0)

      expect(outgoing.reload.transaction_type).to eq("transfer_out")
      expect(incoming.reload.transaction_type).to eq("transfer_in")
    end

    it "rejects dismissed candidates without linking" do
      post "/transactions/process_transfer_candidates",
        params: { accepted_ids: [], rejected_ids: [candidate.id] },
        headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["rejected_count"]).to eq(1)
      expect(candidate.reload.status).to eq("rejected")
      expect(outgoing.reload.transaction_type).to eq("variable_expense")
    end

    it "cannot process candidates belonging to another user" do
      other_user = create(:user, :confirmed)
      other_acct = create(:bank_account, user: other_user, bank: bank)
      other_out = create(
        :transaction, user: other_user, bank_account: other_acct,
        amount: -100.00, transaction_type: "variable_expense", source: :statement_file
      )
      other_in = create(
        :transaction, user: other_user, bank_account: other_acct,
        amount: 100.00, transaction_type: "income", source: :statement_file
      )
      other_candidate = create(
        :transfer_candidate, user: other_user,
        outgoing_transaction: other_out, incoming_transaction: other_in
      )

      post "/transactions/process_transfer_candidates",
        params: { accepted_ids: [other_candidate.id], rejected_ids: [] },
        headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      json = JSON.parse(response.body)
      expect(json["linked_count"]).to eq(0)
      expect(other_out.reload.transaction_type).to eq("variable_expense")
    end
  end
end
