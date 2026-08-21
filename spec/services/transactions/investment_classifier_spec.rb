# frozen_string_literal: true

require "rails_helper"

RSpec.describe Transactions::InvestmentClassifier, type: :service do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:brokerage) { create(:bank_account, user: user, bank: bank, account_type: "investment") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: brokerage) }

  def row(amount, type:, description: "Movimiento", account: brokerage, linked: nil)
    create(
      :transaction, user: user, bank_account: account, statement_file: statement_file,
      amount: amount, transaction_type: type, description: description,
      date: Date.new(2026, 7, 15), linked_transfer_id: linked
    )
  end

  describe "#call" do
    it "retypes the repo churn that inflated both totals" do
      maturity = row(8_399.59, type: "income", description: "Vencimiento de Reporto")
      repurchase = row(-8_391.39, type: "variable_expense", description: "Compra en Reporto")
      shares = row(-5_360.50, type: "variable_expense", description: "Compra de Acciones.")

      expect(described_class.call(statement_file).payload).to eq(3)

      expect([maturity, repurchase, shares].map { |t| t.reload.transaction_type })
        .to all(eq("investment"))
    end

    it "leaves rows the reconciler already claimed as transfers" do
      counterpart = row(-7_500.00, type: "variable_expense", account: create(:bank_account, user: user, bank: bank))
      deposit = row(7_500.00, type: "income", description: "DEPOSITO DE EFECTIVO")

      counterpart.update_columns(transaction_type: "transfer_out", linked_transfer_id: deposit.id)
      deposit.update_columns(transaction_type: "transfer_in", linked_transfer_id: counterpart.id)

      described_class.call(statement_file)

      expect(deposit.reload.transaction_type).to eq("transfer_in")
      expect(deposit.linked_transfer_id).to eq(counterpart.id)
    end

    it "does not touch excluded rows" do
      excluded = row(-100.00, type: "excluded")

      described_class.call(statement_file)

      expect(excluded.reload.transaction_type).to eq("excluded")
    end

    it "leaves accounts that are not investment accounts entirely alone" do
      debit = create(:bank_account, user: user, bank: bank, account_type: "debit")
      debit_statement = create(:statement_file, user: user, bank_account: debit)
      salary = create(
        :transaction, user: user, bank_account: debit, statement_file: debit_statement,
        amount: 20_000.00, transaction_type: "income", date: Date.new(2026, 7, 15)
      )

      expect(described_class.call(debit_statement).payload).to eq(0)
      expect(salary.reload.transaction_type).to eq("income")
    end

    it "only touches rows belonging to the statement it was given" do
      other_statement = create(:statement_file, user: user, bank_account: brokerage)
      untouched = create(
        :transaction, user: user, bank_account: brokerage, statement_file: other_statement,
        amount: 500.00, transaction_type: "income", date: Date.new(2026, 6, 1)
      )

      row(100.00, type: "income")
      described_class.call(statement_file)

      expect(untouched.reload.transaction_type).to eq("income")
    end

    it "is idempotent" do
      row(8_399.59, type: "income", description: "Vencimiento de Reporto")

      expect(described_class.call(statement_file).payload).to eq(1)
      expect(described_class.call(statement_file).payload).to eq(0)
    end

    it "clears the auto-created savings and debt links it invalidates" do
      tx = row(-5_360.50, type: "variable_expense", description: "Compra de Acciones.")
      saving = create(:saving, user: user, opening_balance_date: Date.new(2026, 7, 1))
      SavingTransaction.create!(saving: saving, transaction_record: tx, amount_applied: tx.amount, manual: false)

      described_class.call(statement_file)

      expect(SavingTransaction.where(transaction_id: tx.id)).to be_empty
    end

    it "keeps savings links the user made by hand" do
      tx = row(-5_360.50, type: "variable_expense", description: "Compra de Acciones.")
      saving = create(:saving, user: user, opening_balance_date: Date.new(2026, 7, 1))
      SavingTransaction.create!(saving: saving, transaction_record: tx, amount_applied: tx.amount, manual: true)

      described_class.call(statement_file)

      expect(SavingTransaction.where(transaction_id: tx.id)).not_to be_empty
    end
  end

  # The real July 2026 GBM statement, row for row, as it sits in production today.
  describe "against the real GBM statement" do
    MATURITIES = [
      899.61, 898.74, 8_399.59, 8_391.39, 999.53, 999.71, 999.92, 1_001.39, 1_001.70,
      1_071.32, 1_071.45, 1_071.76, 1_072.01, 1_072.21, 8_486.27, 7_580.53
    ].freeze

    REPURCHASES = [
      898.74, 8_399.59, 8_391.39, 999.53, 999.71, 999.92, 1_001.39, 1_001.70, 1_071.32,
      1_071.45, 1_071.76, 1_072.01, 1_072.21, 8_486.27, 7_580.53, 2_682.38
    ].freeze

    SHARE_BUYS = [
      5_360.50, 2_041.01, 5_090.18, 2_785.65, 610.93, 1_730.60, 1_507.96, 1_357.07, 301.57
    ].freeze

    before do
      MATURITIES.each { |a| row(a, type: "income", description: "Vencimiento de Reporto") }
      REPURCHASES.each { |a| row(-a, type: "variable_expense", description: "Compra en Reporto") }
      SHARE_BUYS.each { |a| row(-a, type: "variable_expense", description: "Compra de Acciones.") }
      row(7_500.64, type: "income", description: "DEPOSITO DE EFECTIVO POR TRASPASO")

      2.times do
        counterpart = create(
          :transaction, user: user, bank_account: create(:bank_account, user: user, bank: bank),
          amount: -7_500.00, transaction_type: "variable_expense", date: Date.new(2026, 7, 20)
        )
        deposit = row(7_500.00, type: "income", description: "DEPOSITO DE EFECTIVO")
        counterpart.update_columns(transaction_type: "transfer_out", linked_transfer_id: deposit.id)
        deposit.update_columns(transaction_type: "transfer_in", linked_transfer_id: counterpart.id)
      end
    end

    it "starts from the numbers production reports today" do
      expect(statement_file.transactions.count).to eq(44)
      expect(statement_file.transactions.where(transaction_type: "income").sum(:amount))
        .to be_within(0.01).of(52_517.77)
      expect(statement_file.transactions.where(transaction_type: "variable_expense").sum(:amount))
        .to be_within(0.01).of(-67_585.37)
    end

    it "leaves nothing in income or spending" do
      described_class.call(statement_file)

      expect(statement_file.transactions.where(transaction_type: "income").sum(:amount)).to eq(0)
      expect(statement_file.transactions.where(transaction_type: %w[fixed_expense variable_expense]).sum(:amount))
        .to eq(0)
    end

    it "types the churn as investment and keeps the reconciled deposits as transfers" do
      described_class.call(statement_file)

      expect(statement_file.transactions.where(transaction_type: "investment").count).to eq(42)
      expect(statement_file.transactions.where(transaction_type: "transfer_in").count).to eq(2)
    end

    # Retyping moves no money, so the ledger still lands on the closing cash balance
    # GBM printed on page 2: efectivo inicial 74.89 + rows = 7.29.
    it "still reconciles to the statement's own closing cash balance" do
      expect { described_class.call(statement_file) }
        .not_to change { statement_file.transactions.sum(:amount).round(2) }

      expect(74.89 + statement_file.transactions.sum(:amount)).to be_within(0.01).of(7.29)
    end
  end
end
