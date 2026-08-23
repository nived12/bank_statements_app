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

  context "when the parser yields nothing usable" do
    it "falls back to full AI extraction when the parser reports failure" do
      allow(parser).to receive(:call).and_return(
        ApplicationService::Response.new(
          success: false, payload: nil,
          errors: ActiveModel::Errors.new(statement_file).tap { |e| e.add(:base, "unparseable") }
        )
      )
      expect(Statements::PiiHandler).to receive(:redact_text).and_return(redacted_text: "clean")
      expect(Ai::PostProcessor).to receive(:call).with(hash_including(:raw_text)).and_return(
        ApplicationService::Response.new(success: true, payload: { "transactions" => [] }, errors: nil)
      )

      described_class.call(statement_file, "raw text")
    end

    it "survives the parser raising and falls back rather than erroring the statement" do
      allow(parser).to receive(:call).and_raise(StandardError, "boom")
      allow(Statements::PiiHandler).to receive(:redact_text).and_return(redacted_text: "clean")
      allow(Ai::PostProcessor).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: { "transactions" => [] }, errors: nil)
      )

      described_class.call(statement_file, "raw text")

      expect(statement_file.reload.status).not_to eq("error")
    end

    it "goes to AI extraction when the parser returns an empty transaction list" do
      allow(parser).to receive(:call).and_return(
        ApplicationService::Response.new(
          success: true, payload: { "transactions" => [] }, errors: nil
        )
      )
      allow(Statements::PiiHandler).to receive(:redact_text).and_return(redacted_text: "clean")
      allow(Ai::PostProcessor).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: { "transactions" => [] }, errors: nil)
      )

      expect { described_class.call(statement_file, "raw text") }
        .not_to change { statement_file.transactions.count }
    end
  end

  context "when the bank has no deterministic parser" do
    it "skips straight to AI extraction" do
      allow(bank_account).to receive(:parser_class).and_return(Ai::PostProcessor)
      allow(Statements::PiiHandler).to receive(:redact_text).and_return(redacted_text: "clean")
      expect(Ai::PostProcessor).to receive(:call).with(hash_including(:raw_text)).and_return(
        ApplicationService::Response.new(success: true, payload: { "transactions" => [] }, errors: nil)
      )

      described_class.call(statement_file, "raw text")
    end
  end

  context "when AI extraction itself fails" do
    it "returns the extractor's failure rather than importing nothing silently" do
      allow(parser).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: { "transactions" => [] }, errors: nil)
      )
      allow(Statements::PiiHandler).to receive(:redact_text).and_return(redacted_text: "clean")
      allow(Ai::PostProcessor).to receive(:call).and_return(
        ApplicationService::Response.new(
          success: false, payload: nil,
          errors: ActiveModel::Errors.new(statement_file).tap { |e| e.add(:base, "gemini down") }
        )
      )

      expect(described_class.call(statement_file, "raw text")).to be_failure
    end
  end

  context "when the AI call fails" do
    # The parser already produced usable rows, so losing categorization is not a reason
    # to lose the statement.
    it "still imports the parser's transactions" do
      allow(Ai::PostProcessor).to receive(:call).and_return(
        ApplicationService::Response.new(
          success: false, payload: nil,
          errors: ActiveModel::Errors.new(statement_file).tap { |e| e.add(:base, "gemini down") }
        )
      )

      described_class.call(statement_file, "raw text")

      expect(statement_file.transactions.count).to eq(1)
    end
  end
end
