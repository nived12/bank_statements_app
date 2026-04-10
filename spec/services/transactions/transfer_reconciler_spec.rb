require "rails_helper"

RSpec.describe Transactions::TransferReconciler, type: :service do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:account_a) { create(:bank_account, user: user, bank: bank) }
  let(:account_b) { create(:bank_account, user: user, bank: bank) }

  let(:service) { described_class.new(user) }

  describe "#call" do
    context "when there are no unlinked transactions" do
      it "returns success with zero counts" do
        result = service.call
        expect(result).to be_success
        expect(result.payload).to eq({ auto_linked: 0, candidates_created: 0 })
      end
    end

    context "high confidence: exact amount + same date + single match" do
      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA A CUENTA 1234",
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
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO TRANSFERENCIA 1234",
          source: :statement_file
        )
      end

      it "auto-links the pair as transfer_out and transfer_in" do
        result = service.call

        expect(result).to be_success
        expect(result.payload[:auto_linked]).to eq(1)
        expect(result.payload[:candidates_created]).to eq(0)

        outgoing.reload
        incoming.reload

        expect(outgoing.transaction_type).to eq("transfer_out")
        expect(incoming.transaction_type).to eq("transfer_in")
        expect(outgoing.linked_transfer_id).to eq(incoming.id)
        expect(incoming.linked_transfer_id).to eq(outgoing.id)
      end
    end

    context "medium confidence: exact amount + date 1 day apart" do
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

      it "creates a TransferCandidate instead of auto-linking" do
        result = service.call

        expect(result).to be_success
        expect(result.payload[:auto_linked]).to eq(0)
        expect(result.payload[:candidates_created]).to eq(1)

        outgoing.reload
        incoming.reload

        expect(outgoing.transaction_type).to eq("variable_expense")
        expect(incoming.transaction_type).to eq("income")
        expect(outgoing.linked_transfer_id).to be_nil

        candidate = TransferCandidate.last
        expect(candidate.outgoing_transaction).to eq(outgoing)
        expect(candidate.incoming_transaction).to eq(incoming)
        expect(candidate.status).to eq("pending")
        expect(candidate.user).to eq(user)
      end
    end

    context "no match: date difference exceeds 1 day" do
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
          date: Date.new(2025, 3, 18),
          description: "DEPOSITO",
          source: :statement_file
        )
      end

      it "does not match" do
        result = service.call

        expect(result.payload[:auto_linked]).to eq(0)
        expect(result.payload[:candidates_created]).to eq(0)
      end
    end

    context "same account rejection" do
      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "PAGO",
          source: :statement_file
        )
      end

      let!(:incoming) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 15),
          description: "DEVOLUCION",
          source: :statement_file
        )
      end

      it "does not match transactions in the same account" do
        result = service.call
        expect(result.payload[:auto_linked]).to eq(0)
        expect(result.payload[:candidates_created]).to eq(0)
      end
    end

    context "already-linked transactions are skipped" do
      let(:other_transaction) { create(:transaction, user: user, bank_account: account_b, source: :statement_file) }

      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "transfer_out",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA",
          source: :statement_file,
          linked_transfer_id: other_transaction.id
        )
      end

      it "skips transactions with existing linked_transfer_id" do
        result = service.call
        expect(result.payload[:auto_linked]).to eq(0)
      end
    end

    context "manual source transactions are ignored" do
      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA",
          source: :manual
        )
      end

      let!(:incoming) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO",
          source: :manual
        )
      end

      it "does not match manual transactions" do
        result = service.call
        expect(result.payload[:auto_linked]).to eq(0)
        expect(result.payload[:candidates_created]).to eq(0)
      end
    end

    context "multiple matches: ambiguous same-date collision" do
      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA SPEI",
          source: :statement_file
        )
      end

      let!(:incoming1) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO SPEI",
          source: :statement_file
        )
      end

      let!(:incoming2) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO SPEI",
          source: :statement_file
        )
      end

      it "creates candidates for all ambiguous matches" do
        result = service.call

        expect(result.payload[:auto_linked]).to eq(0)
        expect(result.payload[:candidates_created]).to eq(2)
        expect(TransferCandidate.pending.count).to eq(2)
      end
    end

    context "multiple matches: tiebreaker by description similarity" do
      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA SPEI CUENTA AHORRO NIVED",
          source: :statement_file
        )
      end

      let!(:incoming_good) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO SPEI CUENTA AHORRO NIVED",
          source: :statement_file
        )
      end

      let!(:incoming_bad) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 15),
          description: "PAGO NOMINA EMPRESA XYZ",
          source: :statement_file
        )
      end

      it "auto-links the match with higher description similarity when advantage is clear" do
        result = service.call

        expect(result.payload[:auto_linked]).to eq(1)

        outgoing.reload
        incoming_good.reload
        incoming_bad.reload

        expect(outgoing.linked_transfer_id).to eq(incoming_good.id)
        expect(incoming_good.linked_transfer_id).to eq(outgoing.id)
        expect(incoming_bad.linked_transfer_id).to be_nil
      end
    end

    context "exact date preference over +/-1 day" do
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

      let!(:same_day) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO",
          source: :statement_file
        )
      end

      let!(:next_day) do
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

      it "prefers the same-date match and auto-links it" do
        result = service.call

        expect(result.payload[:auto_linked]).to eq(1)

        outgoing.reload
        same_day.reload

        expect(outgoing.linked_transfer_id).to eq(same_day.id)
      end
    end

    context "multiple distinct transfer pairs" do
      let!(:outgoing1) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 10),
          description: "TRANSFERENCIA 1",
          source: :statement_file
        )
      end

      let!(:incoming1) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 500.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 10),
          description: "DEPOSITO 1",
          source: :statement_file
        )
      end

      let!(:outgoing2) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -300.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 12),
          description: "TRANSFERENCIA 2",
          source: :statement_file
        )
      end

      let!(:incoming2) do
        create(
          :transaction,
          user: user,
          bank_account: account_b,
          amount: 300.00,
          transaction_type: "income",
          date: Date.new(2025, 3, 12),
          description: "DEPOSITO 2",
          source: :statement_file
        )
      end

      it "matches both pairs correctly" do
        result = service.call

        expect(result.payload[:auto_linked]).to eq(2)

        outgoing1.reload
        outgoing2.reload

        expect(outgoing1.linked_transfer_id).to eq(incoming1.id)
        expect(outgoing2.linked_transfer_id).to eq(incoming2.id)
      end
    end

    context "greedy matching prevention" do
      let(:account_c) { create(:bank_account, user: user, bank: bank) }

      let!(:outgoing_a) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA A",
          source: :statement_file
        )
      end

      let!(:outgoing_c) do
        create(
          :transaction,
          user: user,
          bank_account: account_c,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA C",
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
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO",
          source: :statement_file
        )
      end

      it "only links the incoming to one outgoing, not both" do
        result = service.call

        # One gets linked, the other becomes a candidate or remains unmatched
        incoming.reload
        expect(incoming.linked_transfer_id).to be_present

        linked_outgoing = Transaction.find(incoming.linked_transfer_id)
        other_outgoing = [outgoing_a, outgoing_c].find { |o| o.id != linked_outgoing.id }
        other_outgoing.reload

        expect(other_outgoing.linked_transfer_id).to be_nil
      end
    end

    context "idempotency" do
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
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO",
          source: :statement_file
        )
      end

      it "produces the same result when run twice" do
        first_result = service.call
        expect(first_result.payload[:auto_linked]).to eq(1)

        second_result = described_class.call(user)
        expect(second_result.payload[:auto_linked]).to eq(0)
        expect(second_result.payload[:candidates_created]).to eq(0)
      end
    end

    context "preserves category on reconciled transactions" do
      let(:category) { create(:category, user: user) }

      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: Date.new(2025, 3, 15),
          description: "TRANSFERENCIA",
          category: category,
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
          date: Date.new(2025, 3, 15),
          description: "DEPOSITO",
          category: category,
          source: :statement_file
        )
      end

      it "keeps category_id intact after linking" do
        service.call

        outgoing.reload
        incoming.reload

        expect(outgoing.category_id).to eq(category.id)
        expect(incoming.category_id).to eq(category.id)
      end
    end

    context "date window filtering" do
      let(:transfer_date) { Date.new(2025, 3, 15) }

      let!(:outgoing) do
        create(
          :transaction,
          user: user,
          bank_account: account_a,
          amount: -500.00,
          transaction_type: "variable_expense",
          date: transfer_date,
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
          date: transfer_date,
          description: "DEPOSITO",
          source: :statement_file
        )
      end

      context "when date window includes the transactions" do
        it "matches within the window" do
          result = described_class.call(
            user,
            date_from: transfer_date - 3.days,
            date_to: transfer_date + 3.days
          )

          expect(result.payload[:auto_linked]).to eq(1)
        end
      end

      context "when date window excludes the transactions" do
        it "finds no matches outside the window" do
          result = described_class.call(
            user,
            date_from: transfer_date + 10.days,
            date_to: transfer_date + 20.days
          )

          expect(result.payload[:auto_linked]).to eq(0)
          expect(result.payload[:candidates_created]).to eq(0)
        end
      end

      context "when no date window is provided" do
        it "scans all transactions" do
          result = described_class.call(user)

          expect(result.payload[:auto_linked]).to eq(1)
        end
      end
    end
  end
end
