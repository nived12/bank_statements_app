require "rails_helper"

RSpec.describe BelvoSync::TransactionsFetcher do
  let(:user) { create(:user) }
  let(:belvo_link) { create(:belvo_link, user: user) }
  let(:bank_account) { create(:bank_account, user: user, belvo_link: belvo_link, belvo_account_id: "acc-123") }

  let(:belvo_transactions) do
    [
      {
        "id" => "tx-001",
        "value_date" => "2026-04-01",
        "description" => "PAGO SERVICIO NETFLIX",
        "amount" => -199.00,
        "type" => "OUTFLOW",
        "reference" => nil,
        "merchant" => { "name" => "Netflix" }
      },
      {
        "id" => "tx-002",
        "value_date" => "2026-04-02",
        "description" => "NOMINA EMPRESA SA",
        "amount" => 15000.00,
        "type" => "INFLOW",
        "reference" => nil,
        "merchant" => nil
      }
    ]
  end

  let(:mock_client) { instance_double(Belvo::Client) }
  let(:mock_transactions) { instance_double(Belvo::Transaction) }

  before do
    allow(Belvo::ClientFactory).to receive(:call).and_return(
      ApplicationService::Response.new(success: true, payload: mock_client, errors: nil)
    )
    allow(mock_client).to receive(:transactions).and_return(mock_transactions)
    allow(mock_transactions).to receive(:retrieve).and_return(belvo_transactions)
  end

  describe ".call" do
    it "imports new transactions" do
      expect {
        described_class.call(bank_account: bank_account)
      }.to change(Transaction, :count).by(2)
    end

    it "sets bank_api source" do
      described_class.call(bank_account: bank_account)
      expect(Transaction.last.source).to eq("bank_api")
    end

    it "updates bank account sync status" do
      described_class.call(bank_account: bank_account)
      bank_account.reload
      expect(bank_account.sync_status).to eq("synced")
      expect(bank_account.last_synced_at).to be_present
    end

    it "skips already imported transactions" do
      create(:transaction, user: user, bank_account: bank_account, belvo_transaction_id: "tx-001")

      expect {
        described_class.call(bank_account: bank_account)
      }.to change(Transaction, :count).by(1) # Only tx-002
    end

    context "cross-source duplicate detection" do
      it "skips transactions that match existing manual ones" do
        create(
          :transaction,
          user: user,
          bank_account: bank_account,
          date: Date.parse("2026-04-01"),
          amount: -199.00,
          description: "NETFLIX PAYMENT",
          source: :manual
        )

        expect {
          described_class.call(bank_account: bank_account)
        }.to change(Transaction, :count).by(1) # Only tx-002 (tx-001 is a cross-source dupe)
      end
    end

    it "returns imported count" do
      result = described_class.call(bank_account: bank_account)
      expect(result).to be_success
      expect(result.payload[:imported_count]).to eq(2)
    end
  end
end
