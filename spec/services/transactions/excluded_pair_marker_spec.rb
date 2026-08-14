require "rails_helper"

RSpec.describe Transactions::ExcludedPairMarker, type: :service do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:credit_account) { create(:bank_account, user: user, bank: bank, account_type: "credit") }
  let(:debit_account) { create(:bank_account, user: user, bank: bank, account_type: "debit") }
  let(:statement_file) { create(:statement_file, user: user, bank_account: credit_account) }

  def row(amount:, description:, statement: statement_file, account: credit_account, date: Date.new(2026, 7, 16))
    create(
      :transaction,
      user: user,
      bank_account: account,
      statement_file: statement,
      amount: amount,
      transaction_type: amount.negative? ? "variable_expense" : "income",
      date: date,
      description: description,
      source: :statement_file
    )
  end

  # Every case below is drawn from real production data — the July 2026 audit across
  # all users found exactly four exact-cancels and 48 card payments that matched
  # nothing, which is what makes amount-pairing safe where description matching was not.
  describe ".call" do
    it "excludes a charge and the credit that reverses it" do
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES ZMC 960801538", date: Date.new(2026, 7, 2))
      reversal = row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO CCUOTAS")

      described_class.call(statement_file)

      expect(charge.reload.transaction_type).to eq("excluded")
      expect(reversal.reload.transaction_type).to eq("excluded")
    end

    it "leaves the signs untouched so expenses stay negative" do
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES")
      reversal = row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO CCUOTAS")

      described_class.call(statement_file)

      expect(charge.reload.amount).to eq(-2_210.00)
      expect(reversal.reload.amount).to eq(2_210.00)
    end

    it "contributes nothing to income or expenses once excluded" do
      row(amount: -2_210.00, description: "ZARA CUMBRES")
      row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO CCUOTAS")
      row(amount: -736.67, description: "3MSI nuevas tarjetas", date: Date.new(2026, 7, 17))

      described_class.call(statement_file)
      summary = user.calculate_monthly_summary(Date.new(2026, 7, 1))

      # Only the installment actually owed this month.
      expect(summary[:income]).to eq(0)
      expect(summary[:expenses]).to eq(736.67)
    end

    it "excludes a purchase paid with points" do
      # PAGOS CON PUNTOS against GASOL ES 12050 — no description in common, which is
      # exactly why this is matched on amount rather than wording.
      charge = row(amount: -1_500.00, description: "GASOL ES 12050 HUIXQUILUCAN ESU")
      redemption = row(amount: 1_500.00, description: "PAGOS CON PUNTOS")

      described_class.call(statement_file)

      expect(charge.reload.transaction_type).to eq("excluded")
      expect(redemption.reload.transaction_type).to eq("excluded")
    end

    it "leaves a card payment alone when it matches no single charge" do
      payment = row(amount: 27_578.14, description: "SU PAGO GRACIAS")
      purchase = row(amount: -1_250.50, description: "SUPERMERCADO")

      described_class.call(statement_file)

      expect(payment.reload.transaction_type).to eq("income")
      expect(purchase.reload.transaction_type).to eq("variable_expense")
    end

    it "skips ambiguous matches rather than guessing which charge was reversed" do
      first = row(amount: -800.00, description: "TIENDA UNO")
      second = row(amount: -800.00, description: "TIENDA DOS")
      credit = row(amount: 800.00, description: "ABONO CARGO TRASPASADO CCUOTAS")

      described_class.call(statement_file)

      expect(first.reload.transaction_type).to eq("variable_expense")
      expect(second.reload.transaction_type).to eq("variable_expense")
      expect(credit.reload.transaction_type).to eq("income")
    end

    it "ignores debit accounts entirely" do
      debit_statement = create(:statement_file, user: user, bank_account: debit_account)
      charge = row(amount: -500.00, description: "RETIRO CAJERO", statement: debit_statement, account: debit_account)
      deposit = row(
        amount: 500.00, description: "DEPOSITO EFECTIVO", statement: debit_statement,
        account: debit_account
      )

      described_class.call(debit_statement)

      expect(charge.reload.transaction_type).to eq("variable_expense")
      expect(deposit.reload.transaction_type).to eq("income")
    end

    it "does not pair across statements" do
      other_statement = create(:statement_file, user: user, bank_account: credit_account)
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES")
      reversal = row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO", statement: other_statement)

      described_class.call(statement_file)

      expect(charge.reload.transaction_type).to eq("variable_expense")
      expect(reversal.reload.transaction_type).to eq("income")
    end

    it "is idempotent" do
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES")
      row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO CCUOTAS")

      described_class.call(statement_file)
      expect { described_class.call(statement_file) }.not_to change { charge.reload.transaction_type }
    end

    # The pair's sign is not implied by its type, so every edit path that derives one
    # from the other has to be closed off — otherwise a routine edit turns a pair that
    # nets to zero into a doubled expense.
    it "refuses amount and type edits once excluded" do
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES")
      row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO CCUOTAS")
      described_class.call(statement_file)

      Current.user = user
      result = Transactions::Updater.call(charge.id, { amount: -9_999.00 })

      expect(result).not_to be_success
      expect(charge.reload.amount).to eq(-2_210.00)
      expect(charge.transaction_type).to eq("excluded")
    end

    it "still allows harmless edits like recategorising" do
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES")
      row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO CCUOTAS")
      described_class.call(statement_file)
      category = user.categories.first

      Current.user = user
      result = Transactions::Updater.call(charge.id, { category_id: category.id })

      expect(result).to be_success
      expect(charge.reload.category_id).to eq(category.id)
    end

    # Rows are auto-linked to savings and debts on create, before this service runs.
    # Without cleanup a cancelled purchase keeps counting toward a debt's progress —
    # the Transaction callback will not clear it, since its clearing branch fires only
    # when category, account, date or amount change, and none of those do here.
    it "drops auto-created savings and debts links" do
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES")
      credit = row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO CCUOTAS")
      debt = create(:debt, user: user)
      auto = DebtTransaction.create!(debt: debt, transaction_record: charge, amount_applied: 2_210.00, manual: false)
      manual = DebtTransaction.create!(debt: debt, transaction_record: credit, amount_applied: 2_210.00, manual: true)

      described_class.call(statement_file)

      expect(DebtTransaction.exists?(auto.id)).to be(false)
      expect(DebtTransaction.exists?(manual.id)).to be(true)
    end

    it "never touches rows already linked as a transfer" do
      charge = row(amount: -2_210.00, description: "ZARA CUMBRES")
      reversal = row(amount: 2_210.00, description: "ABONO CARGO TRASPASADO")
      charge.update_columns(transaction_type: "transfer_out", linked_transfer_id: reversal.id)
      reversal.update_columns(transaction_type: "transfer_in", linked_transfer_id: charge.id)

      described_class.call(statement_file)

      expect(charge.reload.transaction_type).to eq("transfer_out")
      expect(reversal.reload.transaction_type).to eq("transfer_in")
    end
  end
end
