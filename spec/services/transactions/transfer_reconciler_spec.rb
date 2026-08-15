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

    context "within the match window but not the same day" do
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

      # Banks disagree about which date they print for the same SPEI, so a gap of a
      # few days is normal. It is offered for review rather than auto-linked.
      it "proposes a candidate but never auto-links" do
        result = service.call

        expect(result.payload[:auto_linked]).to eq(0)
        expect(result.payload[:candidates_created]).to eq(1)
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

      # Two equally plausible outgoings for one incoming: nothing distinguishes them,
      # so both are offered for review. Picking one by loop order is what linked a
      # MERCADOPAGO card purchase to an unrelated SPEI in production.
      it "links neither and asks the user instead" do
        result = service.call

        expect(result.payload[:auto_linked]).to eq(0)
        expect(result.payload[:candidates_created]).to eq(2)

        expect(incoming.reload.linked_transfer_id).to be_nil
        expect(outgoing_a.reload.linked_transfer_id).to be_nil
        expect(outgoing_c.reload.linked_transfer_id).to be_nil
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

  # Every scenario below is reduced from real production data — see the July 2026
  # investigation. They are the cases the amount+date-only matcher got wrong.
  describe "matching on the SPEI tracking key" do
    let(:account_c) { create(:bank_account, user: user, bank: bank) }

    def transfer_row(account:, amount:, date:, description:, tracking_key: nil, type: nil)
      create(
        :transaction,
        user: user,
        bank_account: account,
        amount: amount,
        transaction_type: type || (amount.negative? ? "variable_expense" : "income"),
        date: date,
        description: description,
        tracking_key: tracking_key,
        source: :statement_file
      )
    end

    it "links a pair whose statement dates disagree by more than the fuzzy window" do
      # BBVA prints fecha de operación (18-JUL), Santander its posting date (20-JUL).
      # The old ±1 day window could never span this, so $14,000 stayed counted as income.
      key = "2026071840014BMOVP000406328190"
      outgoing = transfer_row(
        account: account_a, amount: -14_000.00, date: Date.new(2026, 7, 20),
        description: "PAGO TRANSFERENCIA SPEI ENVIADO A BBVA MEXICO", tracking_key: key
      )
      incoming = transfer_row(
        account: account_b, amount: 14_000.00, date: Date.new(2026, 7, 18),
        description: "SPEI RECIBIDOSANTANDER 0192778381 014", tracking_key: key
      )

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(1)
      expect(outgoing.reload.transaction_type).to eq("transfer_out")
      expect(incoming.reload.transaction_type).to eq("transfer_in")
      expect(outgoing.linked_transfer_id).to eq(incoming.id)
    end

    it "links a pair the fuzzy matcher would reject on description alone" do
      key = "2026070340014BMOVP000403807730"
      outgoing = transfer_row(
        account: account_a, amount: -45_000.00, date: Date.new(2026, 7, 3),
        description: "PAGO TRANSFERENCIA SPEI ENVIADO A BANORTE", tracking_key: key
      )
      incoming = transfer_row(
        account: account_b, amount: 45_000.00, date: Date.new(2026, 7, 3),
        description: "SPEI RECIBIDO, BCO:0014 SANTANDER", tracking_key: key
      )

      described_class.call(user)

      expect(outgoing.reload.transaction_type).to eq("transfer_out")
      expect(incoming.reload.transaction_type).to eq("transfer_in")
    end

    # SPEI commissions are billed as their own statement line, never netted out of the
    # transfer, so both banks print the same figure — all nine shared keys in production
    # match to the cent. Unequal amounts therefore mean the key is wrong, not that a fee
    # was deducted, and the backfill can produce exactly that: it maps every amount in an
    # 8-line window to the clave printed there, so a running balance can pick one up.
    # Production hit this — one clave landed on a -30,625.23 charge and a +7,500 deposit.
    it "does not link two rows sharing a key when the amounts differ" do
      key = "MBAN01002604090068081347"
      outgoing = transfer_row(
        account: account_a, amount: -30_625.23, date: Date.new(2026, 4, 9),
        description: "PAGO TRANSFERENCIA SPEI ENVIADO", tracking_key: key
      )
      incoming = transfer_row(
        account: account_b, amount: 7_500.00, date: Date.new(2026, 4, 9),
        description: "SPEI RECIBIDO", tracking_key: key
      )

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(outgoing.reload.transaction_type).to eq("variable_expense")
      expect(incoming.reload.transaction_type).to eq("income")
      expect(outgoing.linked_transfer_id).to be_nil
    end

    it "does not link two rows sharing a key on the same account" do
      key = "2026070940014BMOVP000449965460"
      outgoing = transfer_row(
        account: account_a, amount: -1_000.00, date: Date.new(2026, 7, 9),
        description: "PAGO TRANSFERENCIA SPEI", tracking_key: key
      )
      incoming = transfer_row(
        account: account_a, amount: 1_000.00, date: Date.new(2026, 7, 9),
        description: "SPEI RECIBIDO", tracking_key: key
      )

      described_class.call(user)

      expect(outgoing.reload.transaction_type).to eq("variable_expense")
      expect(incoming.reload.transaction_type).to eq("income")
    end

    # ExcludedPairMarker runs before the reconciler in ImportFinalizer, so excluded
    # rows are already present. Relinking one half as a transfer would retype it and
    # orphan its partner, putting a cancelled purchase back into the expense totals.
    it "never relinks a row that is already excluded" do
      key = "2026071640014BMOVP000446382100"
      charge = transfer_row(
        account: account_a, amount: -2_210.00, date: Date.new(2026, 7, 2),
        description: "ZARA CUMBRES", tracking_key: key, type: "excluded"
      )
      credit = transfer_row(
        account: account_b, amount: 2_210.00, date: Date.new(2026, 7, 16),
        description: "ABONO CARGO TRASPASADO CCUOTAS", tracking_key: key, type: "excluded"
      )

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(charge.reload.transaction_type).to eq("excluded")
      expect(credit.reload.transaction_type).to eq("excluded")
      expect(charge.linked_transfer_id).to be_nil
    end

    it "ignores a blank tracking key rather than pairing every keyless row" do
      transfer_row(
        account: account_a, amount: -700.00, date: Date.new(2026, 7, 5),
        description: "COMPRA SUPERMERCADO", tracking_key: nil
      )
      transfer_row(
        account: account_b, amount: 900.00, date: Date.new(2026, 7, 5),
        description: "DEPOSITO EFECTIVO", tracking_key: ""
      )

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
    end
  end

  # Rejecting a candidate is a decision, and the reconciler runs again on every import.
  # Both of these were real: the reported count came from `create_candidate` returning
  # true when it merely *found* a rejected row, so "1 candidato para revisar" opened an
  # empty modal; and a rejected pair that happened to be same-date could be auto-linked
  # outright on the next run, silently overriding the user.
  describe "respecting a rejected candidate" do
    def row(account:, amount:, date:, description:)
      create(
        :transaction,
        user: user,
        bank_account: account,
        amount: amount,
        transaction_type: amount.negative? ? "variable_expense" : "income",
        date: date,
        description: description,
        source: :statement_file
      )
    end

    def reject_pair(outgoing, incoming)
      create(
        :transfer_candidate,
        user: user,
        outgoing_transaction: outgoing,
        incoming_transaction: incoming,
        status: "rejected"
      )
    end

    it "never auto-links a pair the user already rejected" do
      date = Date.new(2026, 7, 9)
      outgoing = row(
        account: account_a, amount: -1_000.00, date: date,
        description: "PAGO TRANSFERENCIA SPEI ENVIADO"
      )
      incoming = row(
        account: account_b, amount: 1_000.00, date: date,
        description: "SPEI RECIBIDO SANTANDER"
      )
      reject_pair(outgoing, incoming)

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(outgoing.reload.transaction_type).to eq("variable_expense")
      expect(incoming.reload.transaction_type).to eq("income")
      expect(outgoing.linked_transfer_id).to be_nil
    end

    # Not hypothetical: rows are keyed long after they are imported. A pair is rejected
    # while keyless, `transfers:backfill_tracking_keys` later assigns both sides the same
    # clave, and the next run auto-links them on the key alone — the phase-2 guard never
    # gets a say, because phase 1 runs first and answers to nothing but the key.
    it "never auto-links a rejected pair that was keyed after the fact" do
      key = "2026070940014BMOVP000449965460"
      outgoing = row(
        account: account_a, amount: -2_000.00, date: Date.new(2026, 7, 9),
        description: "PAGO TRANSFERENCIA SPEI ENVIADO"
      )
      incoming = row(
        account: account_b, amount: 2_000.00, date: Date.new(2026, 7, 11),
        description: "SPEI RECIBIDO SANTANDER"
      )
      reject_pair(outgoing, incoming)
      Transaction.where(id: [outgoing.id, incoming.id]).update_all(tracking_key: key)

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(outgoing.reload.transaction_type).to eq("variable_expense")
      expect(incoming.reload.transaction_type).to eq("income")
    end

    it "does not count a rejected pair as a candidate to review" do
      # The count feeds "N candidatos para revisar", while the modal lists only pending
      # candidates. Counting a rejected row put a number on a link that opened nothing.
      #
      # Both sides speak transfer language and sit three days apart, so the pair reaches
      # the candidate path rather than being auto-linked — without that this spec passes
      # whether or not the fix is present, because `worth_reviewing?` drops a pair with
      # no shared words before `create_candidate` is ever called.
      outgoing = row(
        account: account_a, amount: -680.00, date: Date.new(2026, 3, 15),
        description: "PAGO TRANSFERENCIA SPEI ENVIADO"
      )
      incoming = row(
        account: account_b, amount: 680.00, date: Date.new(2026, 3, 18),
        description: "SPEI RECIBIDO BANAMEX"
      )
      reject_pair(outgoing, incoming)

      result = described_class.call(user)

      expect(result.payload[:candidates_created]).to eq(0)
      expect(user.transfer_candidates.pending.count).to eq(0)
    end
  end

  describe "guarding the fuzzy amount+date match" do
    let(:account_c) { create(:bank_account, user: user, bank: bank) }

    def row(account:, amount:, date:, description:)
      create(
        :transaction,
        user: user,
        bank_account: account,
        amount: amount,
        transaction_type: amount.negative? ? "variable_expense" : "income",
        date: date,
        description: description,
        source: :statement_file
      )
    end

    it "picks the real transfer over a same-day, same-amount card purchase" do
      # Production bug: `MERCADOPAGO ABELARDO -1,000` on the credit card was linked to
      # an incoming SPEI because each outgoing independently saw exactly one candidate.
      # The true counterpart — a Santander transfer of the same amount, same day — was
      # left unlinked, so a real expense was reclassified as a transfer.
      date = Date.new(2026, 7, 9)
      card_purchase = row(
        account: account_a, amount: -1_000.00, date: date,
        description: "MERCADOPAGO ABELARDO"
      )
      real_transfer = row(
        account: account_b, amount: -1_000.00, date: date,
        description: "PAGO TRANSFERENCIA SPEI ENVIADO A BBVA MEXICO CONCEPTO TRANSFERENCIA A NIVED BANCOMER"
      )
      incoming = row(
        account: account_c, amount: 1_000.00, date: date,
        description: "SPEI RECIBIDOSANTANDER 0128238904 014 6845083TRANSFERENCIA A NIVED BANCOMER"
      )

      described_class.call(user)

      expect(real_transfer.reload.transaction_type).to eq("transfer_out")
      expect(incoming.reload.linked_transfer_id).to eq(real_transfer.id)
      expect(card_purchase.reload.transaction_type).to eq("variable_expense")
      expect(card_purchase.linked_transfer_id).to be_nil
    end

    it "never links amounts that merely look close" do
      # A $350.00 incoming SPEI and an ANTHROPIC subscription of $350.58 landed a day
      # apart in production. Widening the amount tolerance would have paired them.
      incoming = row(
        account: account_a, amount: 350.00, date: Date.new(2026, 7, 18),
        description: "SPEI RECIBIDOBANAMEX 0188230643 002"
      )
      unrelated = row(
        account: account_b, amount: -350.58, date: Date.new(2026, 7, 17),
        description: "ANTHROPIC* CLAUDE SUB USD 20.00"
      )

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(incoming.reload.transaction_type).to eq("income")
      expect(unrelated.reload.transaction_type).to eq("variable_expense")
    end

    it "creates a candidate instead of auto-linking when descriptions share nothing" do
      date = Date.new(2026, 7, 11)
      row(account: account_a, amount: -2_500.00, date: date, description: "ALPHA BETA GAMMA")
      row(account: account_b, amount: 2_500.00, date: date, description: "DELTA EPSILON ZETA")

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(result.payload[:candidates_created]).to eq(1)
    end

    it "still auto-links a same-day pair whose descriptions clearly correspond" do
      date = Date.new(2026, 7, 11)
      outgoing = row(
        account: account_a, amount: -2_500.00, date: date,
        description: "TRANSFERENCIA A CUENTA 1234"
      )
      row(account: account_b, amount: 2_500.00, date: date, description: "DEPOSITO TRANSFERENCIA 1234")

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(1)
      expect(outgoing.reload.transaction_type).to eq("transfer_out")
    end

    # Reduced from local data: a Santander card purchase and an unrelated STP deposit,
    # $1,000 apiece, three days apart, zero words in common. Widening the window to ±3
    # days made it eligible, and the review modal used to arrive pre-checked — so the
    # primary button would have destroyed $1,000 of real income and real spending.
    # Nothing here says "transfer" on either side; do not put it in front of the user.
    it "does not propose a pair with no transfer signal at all" do
      row(
        account: account_a, amount: -1_000.00, date: Date.new(2026, 7, 9),
        description: "MERCADOPAGO ABELARDO"
      )
      row(
        account: account_b, amount: 1_000.00, date: Date.new(2026, 7, 12),
        description: "COMPRA EN TIENDA"
      )

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(result.payload[:candidates_created]).to eq(0)
      expect(user.transfer_candidates.count).to eq(0)
    end

    it "still proposes a pair when the descriptions share anything at all" do
      row(
        account: account_a, amount: -1_000.00, date: Date.new(2026, 7, 9),
        description: "MERCADOPAGO ABELARDO"
      )
      row(
        account: account_b, amount: 1_000.00, date: Date.new(2026, 7, 12),
        description: "ABELARDO REEMBOLSO"
      )

      expect(described_class.call(user).payload[:candidates_created]).to eq(1)
    end

    it "matches across a 3 day gap as a reviewable candidate" do
      row(
        account: account_a, amount: -1_000.00, date: Date.new(2026, 7, 27),
        description: "PAGO TRANSFERENCIA SPEI ENVIADO BANCOMER"
      )
      row(
        account: account_b, amount: 1_000.00, date: Date.new(2026, 7, 25),
        description: "SPEI RECIBIDOSANTANDER TRANSFERENCIA BANCOMER"
      )

      result = described_class.call(user)

      expect(result.payload[:auto_linked]).to eq(0)
      expect(result.payload[:candidates_created]).to eq(1)
    end
  end

  describe "candidate bookkeeping" do
    let(:account_c) { create(:bank_account, user: user, bank: bank) }

    it "does not create a candidate when either side is already linked" do
      # The UI counts `TransferCandidate.linkable`, so candidates whose transactions
      # are already paired were reported to the user but never rendered — the
      # "2 candidatos para revisar" link that opened nothing.
      date = Date.new(2026, 7, 14)
      already_out = create(
        :transaction, user: user, bank_account: account_a, amount: -3_000.00,
        transaction_type: "variable_expense", date: date,
        description: "PAGO TRANSFERENCIA SPEI", source: :statement_file
      )
      already_in = create(
        :transaction, user: user, bank_account: account_b, amount: 3_000.00,
        transaction_type: "income", date: date,
        description: "SPEI RECIBIDO", source: :statement_file
      )
      already_out.update_columns(transaction_type: "transfer_out", linked_transfer_id: already_in.id)
      already_in.update_columns(transaction_type: "transfer_in", linked_transfer_id: already_out.id)

      create(
        :transaction, user: user, bank_account: account_c, amount: -3_000.00,
        transaction_type: "variable_expense", date: date + 2.days,
        description: "OTRO CARGO", source: :statement_file
      )

      result = described_class.call(user)

      expect(TransferCandidate.linkable.count).to eq(result.payload[:candidates_created])
    end

    it "reports only candidates the review modal can actually show" do
      date = Date.new(2026, 7, 21)
      create(
        :transaction, user: user, bank_account: account_a, amount: -800.00,
        transaction_type: "variable_expense", date: date,
        description: "ALPHA", source: :statement_file
      )
      create(
        :transaction, user: user, bank_account: account_b, amount: 800.00,
        transaction_type: "income", date: date + 2.days,
        description: "OMEGA", source: :statement_file
      )

      result = described_class.call(user)

      expect(result.payload[:candidates_created]).to eq(user.transfer_candidates.pending.linkable.count)
    end
  end
end
