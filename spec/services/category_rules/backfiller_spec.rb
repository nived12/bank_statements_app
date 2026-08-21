require "rails_helper"

RSpec.describe CategoryRules::Backfiller do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:parent_category) { create(:category, user: user, name: "Deudas y Prestamos") }
  let(:rule_category) do
    create(:category, user: user, name: "Credito Automotriz", parent: parent_category)
  end
  let(:wrong_category) { create(:category, user: user, name: "Prestamos Personales") }

  let!(:rule) do
    create(
      :category_rule, user: user, category: rule_category,
      pattern: "pago de prestamo total de recibo", match_type: "contains"
    )
  end

  def statement_transaction(category:, description: "PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO")
    create(
      :transaction,
      user: user, bank_account: bank_account, statement_file: statement_file,
      description: description, category: category, source: :statement_file
    )
  end

  describe "dry run" do
    it "reports the change without touching the transaction" do
      transaction = statement_transaction(category: wrong_category)

      result = described_class.call(user: user)

      expect(result.payload[:changes]).to contain_exactly(
        hash_including(transaction_id: transaction.id, to_category_id: rule_category.id)
      )
      expect(transaction.reload.category_id).to eq(wrong_category.id)
    end

    it "does not inflate the rule's hit count" do
      statement_transaction(category: wrong_category)

      expect { described_class.call(user: user) }.not_to change { rule.reload.hits_count }
    end
  end

  describe "when applying" do
    it "moves the transaction to the rule's category" do
      transaction = statement_transaction(category: wrong_category)

      described_class.call(user: user, apply: true)

      expect(transaction.reload.category_id).to eq(rule_category.id)
    end

    it "counts the hit against the rule" do
      statement_transaction(category: wrong_category)

      expect { described_class.call(user: user, apply: true) }
        .to change { rule.reload.hits_count }.by(1)
    end

    it "leaves transactions the rule already agrees with alone" do
      transaction = statement_transaction(category: rule_category)

      result = described_class.call(user: user, apply: true)

      expect(result.payload[:changes]).to be_empty
      expect(transaction.reload.updated_at).to eq(transaction.updated_at)
    end

    it "ignores manually entered transactions" do
      transaction = create(
        :transaction,
        user: user, bank_account: bank_account, statement_file: nil,
        description: "PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO",
        category: wrong_category, source: :manual
      )

      described_class.call(user: user, apply: true)

      expect(transaction.reload.category_id).to eq(wrong_category.id)
    end

    it "ignores transactions no rule matches" do
      transaction = statement_transaction(category: wrong_category, description: "OXXO SUCURSAL 12")

      described_class.call(user: user, apply: true)

      expect(transaction.reload.category_id).to eq(wrong_category.id)
    end

    it "relinks the transaction to a debt that syncs on the rule's category" do
      debt = create(
        :debt, user: user, status: "active",
        calculation_settings: { "expense" => "positive" }
      )
      debt.categories << rule_category
      debt.bank_accounts << bank_account
      debt.update!(auto_sync_transactions: true)
      transaction = statement_transaction(category: wrong_category)

      described_class.call(user: user, apply: true)

      expect(debt.reload.transactions).to include(transaction)
    end
  end
end
