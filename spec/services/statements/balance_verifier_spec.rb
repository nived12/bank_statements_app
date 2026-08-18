# frozen_string_literal: true

require "rails_helper"

RSpec.describe Statements::BalanceVerifier, type: :service do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:account) { create(:bank_account, user: user, bank: bank, account_type: "debit") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: account) }

  def summarise(initial:, final:)
    create(
      :statement_financial_summary,
      statement_file: statement_file,
      initial_balance: initial,
      final_balance: final
    )
  end

  def row(amount, type: "income")
    create(
      :transaction, user: user, bank_account: account, statement_file: statement_file,
      amount: amount, transaction_type: type, date: Date.new(2026, 7, 15)
    )
  end

  describe "#call" do
    context "when the rows reproduce the statement's own closing balance" do
      before do
        summarise(initial: 25_074.62, final: 44_857.06)
        row(22_500.64)
        row(-2_718.20, type: "variable_expense")
      end

      it "reports the statement as balanced" do
        result = described_class.call(statement_file)

        expect(result).to be_success
        expect(result.payload[:balanced]).to be true
        expect(result.payload[:discrepancy]).to be_within(0.01).of(0)
      end
    end

    context "when rows are missing or misclassified" do
      before do
        summarise(initial: 25_074.62, final: 44_857.06)
        row(22_500.64)
      end

      it "reports the statement as unbalanced" do
        result = described_class.call(statement_file)

        expect(result.payload[:balanced]).to be false
      end

      it "reports how far off it is" do
        result = described_class.call(statement_file)

        expect(result.payload[:discrepancy]).to be_within(0.01).of(2_718.20)
      end

      it "records the discrepancy on the summary so it is not merely logged" do
        described_class.call(statement_file)

        expect(statement_file.financial_summary.reload.statement_type_data["balance_check"])
          .to include("balanced" => false)
      end
    end

    context "tolerance" do
      before { summarise(initial: 0, final: 100) }

      it "accepts a sub-peso rounding difference" do
        row(100.004)

        expect(described_class.call(statement_file).payload[:balanced]).to be true
      end

      it "rejects a difference of several pesos" do
        row(95.00)

        expect(described_class.call(statement_file).payload[:balanced]).to be false
      end
    end

    describe "declining to judge" do
      # The model validates both balances, so this state is only reachable via
      # update_columns or pre-validation rows. Stubbed rather than persisted.
      it "skips when the statement declared no balances" do
        summary = summarise(initial: 0, final: 100)
        allow(summary).to receive(:initial_balance).and_return(nil)
        allow(statement_file).to receive(:financial_summary).and_return(summary)
        row(500)

        result = described_class.call(statement_file)

        expect(result).to be_success
        expect(result.payload[:skipped]).to be true
      end

      it "skips when there is no financial summary at all" do
        row(500)

        expect(described_class.call(statement_file).payload[:skipped]).to be true
      end

      # extract_decimal turns a key the AI never emitted into 0.0, so "opened at zero,
      # closed at zero, with transactions" means undeclared rather than genuinely empty.
      # A real GBM upload landed here and was flagged for a discrepancy it did not have.
      it "skips when both balances are zero but rows exist" do
        summarise(initial: 0, final: 0)
        row(-67.60, type: "variable_expense")

        expect(described_class.call(statement_file).payload[:skipped]).to be true
      end

      it "still judges a genuinely empty statement" do
        summarise(initial: 0, final: 0)

        expect(described_class.call(statement_file).payload[:skipped]).to be false
      end

      it "skips brokerage statements, whose declared balance is portfolio value" do
        account.update!(account_type: "investment")
        summarise(initial: 25_074.62, final: 44_857.06)
        row(-67.60, type: "variable_expense")

        expect(described_class.call(statement_file).payload[:skipped]).to be true
      end
    end

    # Figures taken from two real card statements. A card tracks debt, so the identity
    # runs the other way: charges are stored negative but raise what is owed.
    describe "credit cards" do
      before { account.update!(account_type: "credit") }

      it "reconciles a Santander statement that opened at zero" do
        summarise(initial: 0.0, final: 21_391.18)
        row(-25_915.26, type: "variable_expense")   # cargos regulares
        row(-2_262.04, type: "variable_expense")    # cargos a meses
        row(6_786.12)                               # pagos y abonos

        result = described_class.call(statement_file)

        expect(result.payload[:balanced]).to be true
        expect(result.payload[:discrepancy]).to be_within(0.01).of(0)
      end

      it "reconciles a BBVA statement carrying debt forward" do
        summarise(initial: 21_635.77, final: 35_744.98)
        row(-38_788.00, type: "variable_expense")
        row(24_678.79)

        expect(described_class.call(statement_file).payload[:balanced]).to be true
      end

      it "flags a card statement that is missing a charge" do
        summarise(initial: 21_635.77, final: 35_744.98)
        row(-30_000.00, type: "variable_expense")
        row(24_678.79)

        result = described_class.call(statement_file)

        expect(result.payload[:balanced]).to be false
        expect(result.payload[:discrepancy]).to be_within(0.01).of(-8_788.00)
      end

      # The debit identity applied to a card would be out by twice the period's movement,
      # so this guards against the two branches ever being swapped.
      it "does not simply add the movements as a debit account would" do
        summarise(initial: 0.0, final: 21_391.18)
        row(-21_391.18, type: "variable_expense")

        expect(described_class.call(statement_file).payload[:balanced]).to be true
      end
    end

    it "never raises, whatever the data" do
      summarise(initial: 0, final: 100)
      allow(statement_file).to receive(:transactions).and_raise(StandardError, "boom")

      expect { described_class.call(statement_file) }.not_to raise_error
    end
  end
end
