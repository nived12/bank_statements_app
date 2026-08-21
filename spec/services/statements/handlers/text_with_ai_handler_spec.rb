require "rails_helper"

RSpec.describe Statements::Handlers::TextWithAiHandler do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) do
    create(:statement_file, user: user, bank_account: bank_account, processing_strategy: :text_with_ai)
  end
  let(:parent_category) { create(:category, user: user, name: "Deudas y Prestamos") }
  let(:rule_category) do
    create(:category, user: user, name: "Credito Automotriz", parent: parent_category)
  end

  let(:parsed_transactions) do
    [
      {
        "date" => "2026-06-19",
        "description" => "PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO",
        "amount" => "-13975.23",
        "transaction_type" => "variable_expense"
      }
    ]
  end

  let(:parser) { class_double(PdfParser::BbvaSavingsAccount) }

  before do
    allow(bank_account).to receive(:parser_class).and_return(parser)
    allow(BankAccount).to receive(:find).and_return(bank_account)
    allow(statement_file).to receive(:bank_account).and_return(bank_account)
    allow(parser).to receive(:name).and_return("PdfParser::Stub")
    allow(parser).to receive(:call).and_return(
      ApplicationService::Response.new(
        success: true, payload: { "transactions" => parsed_transactions }, errors: nil
      )
    )
  end

  # Sending rows to Gemini that a rule already categorizes is spend for nothing. The
  # rules run again in import_and_finalize, so this pass is purely a cost filter.
  context "when rules already cover every transaction" do
    let!(:rule) do
      create(
        :category_rule, user: user, category: rule_category,
        pattern: "pago de prestamo total de recibo", match_type: "contains"
      )
    end

    it "does not call the AI at all" do
      expect(Ai::PostProcessor).not_to receive(:call)

      described_class.call(statement_file, "raw text")
    end

    it "still imports the transaction with the rule's category" do
      described_class.call(statement_file, "raw text")

      expect(statement_file.transactions.sole.category_id).to eq(rule_category.id)
    end

    # The pre-AI pass and the finalizer match the same rows, so counting in both
    # would report every hit twice.
    it "counts the hit exactly once" do
      expect { described_class.call(statement_file, "raw text") }
        .to change { rule.reload.hits_count }.by(1)
    end
  end

  context "when no rule matches" do
    it "sends the transaction to the AI" do
      expect(Ai::PostProcessor).to receive(:call).with(
        hash_including(transactions: parsed_transactions)
      ).and_return(
        ApplicationService::Response.new(
          success: true, payload: { "transactions" => parsed_transactions }, errors: nil
        )
      )

      described_class.call(statement_file, "raw text")
    end
  end

  context "when a rule covers only some transactions" do
    let(:two_transactions) do
      parsed_transactions + [
        {
          "date" => "2026-06-20",
          "description" => "OXXO SUCURSAL 12",
          "amount" => "-120.00",
          "transaction_type" => "variable_expense"
        }
      ]
    end

    before do
      create(
        :category_rule, user: user, category: rule_category,
        pattern: "pago de prestamo total de recibo", match_type: "contains"
      )
      allow(parser).to receive(:call).and_return(
        ApplicationService::Response.new(
          success: true, payload: { "transactions" => two_transactions }, errors: nil
        )
      )
    end

    it "sends only the uncovered transaction to the AI" do
      expect(Ai::PostProcessor).to receive(:call) do |args|
        expect(args[:transactions].map { |t| t["description"] }).to eq(["OXXO SUCURSAL 12"])
        ApplicationService::Response.new(
          success: true, payload: { "transactions" => [two_transactions.last] }, errors: nil
        )
      end

      described_class.call(statement_file, "raw text")
    end
  end
end
