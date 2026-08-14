# frozen_string_literal: true

require "rails_helper"
require "rake"

# These tasks exist to repair data that predates transfer reconciliation. They run
# by hand against production, over every user, so the properties that matter are:
# they never touch a key that is already set, a missing statement file is survivable,
# and DRY_RUN really writes nothing.
RSpec.describe "transfers rake tasks", type: :task do
  before(:all) do
    Rake::Task.clear
    Rails.application.load_tasks
  end

  before { Rake::Task[task_name].reenable }

  # Rake reports to stdout; capture it so the suite output stays clean and examples
  # can assert on what the operator is actually told.
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def run
    capture_stdout { Rake::Task[task_name].invoke }
  end

  let(:statement_text) do
    <<~TXT
      18/JUL   20/JUL SPEI RECIBIDOSANTANDER                       14,000.00
               0192778381 014 9788921TRANSFERENCIA A NIVED BANCOMER
               00014580140409590176
               2026071840014BMOVP000406328190
    TXT
  end

  describe "transfers:backfill_tracking_keys" do
    let(:task_name) { "transfers:backfill_tracking_keys" }

    let(:user) { create(:user) }
    let(:bank_account) { create(:bank_account, user: user) }
    let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
    let!(:transaction) do
      create(
        :transaction,
        user: user,
        bank_account: bank_account,
        statement_file: statement_file,
        amount: 14_000.00,
        transaction_type: "income",
        date: Date.new(2026, 7, 18),
        tracking_key: nil
      )
    end

    context "when the statement file is readable" do
      before do
        allow(TransfersBackfill).to receive(:statement_text).and_return(statement_text)
      end

      it "assigns the clave printed with the matching amount" do
        run

        expect(transaction.reload.tracking_key).to eq("2026071840014BMOVP000406328190")
      end

      it "writes nothing under DRY_RUN" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DRY_RUN").and_return("1")

        output = run

        expect(transaction.reload.tracking_key).to be_nil
        expect(output).to include("DRY RUN")
      end

      it "is idempotent" do
        run
        Rake::Task[task_name].reenable
        output = run

        expect(transaction.reload.tracking_key).to eq("2026071840014BMOVP000406328190")
        expect(output).to include("keys_assigned=0")
      end

      it "never overwrites a key that is already set" do
        transaction.update_column(:tracking_key, "MANUALLY0000000000000SET")

        run

        expect(transaction.reload.tracking_key).to eq("MANUALLY0000000000000SET")
      end

      it "covers every user, not just the first" do
        other_user = create(:user)
        other_account = create(:bank_account, user: other_user)
        other_statement = create(:statement_file, user: other_user, bank_account: other_account)
        other_transaction = create(
          :transaction,
          user: other_user, bank_account: other_account, statement_file: other_statement,
          amount: 14_000.00, transaction_type: "income",
          date: Date.new(2026, 7, 18), tracking_key: nil
        )

        run

        expect(other_transaction.reload.tracking_key).to eq("2026071840014BMOVP000406328190")
      end
    end

    context "when the statement file is gone from storage" do
      before do
        allow(TransfersBackfill).to receive(:statement_text).and_return(nil)
      end

      # Statements are sensitive and are not kept forever; three of the author's
      # blobs were already absent. This must be a reported outcome, not a crash.
      it "reports it and leaves the row alone" do
        output = nil

        expect { output = run }.not_to raise_error
        expect(transaction.reload.tracking_key).to be_nil
        expect(output).to include("unreadable=1")
      end
    end
  end

  describe "transfers:reconcile_all" do
    let(:task_name) { "transfers:reconcile_all" }

    let(:user) { create(:user) }
    let(:bank) { create(:bank) }
    let(:account_a) { create(:bank_account, user: user, bank: bank) }
    let(:account_b) { create(:bank_account, user: user, bank: bank) }

    it "links a keyed pair across every user's history" do
      key = "2026071840014BMOVP000406328190"
      outgoing = create(
        :transaction, user: user, bank_account: account_a, amount: -14_000.00,
        transaction_type: "variable_expense", date: Date.new(2026, 7, 20),
        description: "PAGO TRANSFERENCIA SPEI", source: :statement_file, tracking_key: key
      )
      incoming = create(
        :transaction, user: user, bank_account: account_b, amount: 14_000.00,
        transaction_type: "income", date: Date.new(2026, 7, 18),
        description: "SPEI RECIBIDOSANTANDER", source: :statement_file, tracking_key: key
      )

      output = run

      expect(outgoing.reload.transaction_type).to eq("transfer_out")
      expect(incoming.reload.transaction_type).to eq("transfer_in")
      expect(output).to include("auto_linked=1")
    end
  end
end
