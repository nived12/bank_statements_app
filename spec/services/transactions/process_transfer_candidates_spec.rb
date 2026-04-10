require "rails_helper"

RSpec.describe Transactions::ProcessTransferCandidates, type: :service do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:account_a) { create(:bank_account, user: user, bank: bank) }
  let(:account_b) { create(:bank_account, user: user, bank: bank) }

  let!(:outgoing) do
    create(
      :transaction,
      user: user,
      bank_account: account_a,
      amount: -500.00,
      transaction_type: "variable_expense",
      date: Date.new(2025, 3, 15),
      description: "TRANSFERENCIA",
      source: :statement_file
    )
  end

  let!(:incoming) do
    create(
      :transaction,
      user: user,
      bank_account: account_b,
      amount: 500.00,
      transaction_type: "income",
      date: Date.new(2025, 3, 16),
      description: "DEPOSITO",
      source: :statement_file
    )
  end

  let!(:candidate) do
    create(
      :transfer_candidate,
      user: user,
      outgoing_transaction: outgoing,
      incoming_transaction: incoming,
      similarity_score: 0.3,
      status: "pending"
    )
  end

  describe "#call" do
    context "when accepting a candidate" do
      it "links the pair as transfers" do
        result = described_class.call(user, accepted_ids: [candidate.id], rejected_ids: [])

        expect(result).to be_success
        expect(result.payload[:linked_count]).to eq(1)

        outgoing.reload
        incoming.reload
        candidate.reload

        expect(outgoing.transaction_type).to eq("transfer_out")
        expect(incoming.transaction_type).to eq("transfer_in")
        expect(outgoing.linked_transfer_id).to eq(incoming.id)
        expect(incoming.linked_transfer_id).to eq(outgoing.id)
        expect(candidate.status).to eq("accepted")
      end
    end

    context "when rejecting a candidate" do
      it "marks as rejected without linking" do
        result = described_class.call(user, accepted_ids: [], rejected_ids: [candidate.id])

        expect(result).to be_success
        expect(result.payload[:rejected_count]).to eq(1)

        outgoing.reload
        incoming.reload
        candidate.reload

        expect(outgoing.transaction_type).to eq("variable_expense")
        expect(incoming.transaction_type).to eq("income")
        expect(outgoing.linked_transfer_id).to be_nil
        expect(candidate.status).to eq("rejected")
      end
    end

    context "when a transaction is already linked" do
      before do
        other = create(:transaction, user: user, bank_account: account_b, source: :statement_file)
        outgoing.update_column(:linked_transfer_id, other.id)
      end

      it "skips already-linked transactions" do
        result = described_class.call(user, accepted_ids: [candidate.id], rejected_ids: [])

        expect(result).to be_success
        expect(result.payload[:linked_count]).to eq(0)
      end
    end
  end
end
