require "rails_helper"

RSpec.describe Statements::Handlers::VisionHandler do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) do
    create(:statement_file, user: user, bank_account: bank_account, processing_strategy: :vision_ai)
  end

  describe "extraction failures" do
    it "stores the extractor's own reason on the statement file" do
      failed = instance_double(
        ApplicationService::Response,
        success?: false,
        errors: ActiveModel::Errors.new(statement_file).tap do |e|
          e.add(:base, "Vision API error: Gemini stopped early (finishReason: MAX_TOKENS)")
        end
      )
      allow(Statements::VisionExtractor).to receive(:call).and_return(failed)

      described_class.call(statement_file)

      statement_file.reload
      expect(statement_file.status).to eq("error")
      expect(statement_file.error_message).to include("MAX_TOKENS")
    end

    it "falls back to a generic message when the extractor reports no reason" do
      failed = instance_double(
        ApplicationService::Response,
        success?: false,
        errors: ActiveModel::Errors.new(statement_file)
      )
      allow(Statements::VisionExtractor).to receive(:call).and_return(failed)

      described_class.call(statement_file)

      expect(statement_file.reload.error_message).to eq("Vision extraction failed")
    end

    it "returns a failure response" do
      failed = instance_double(
        ApplicationService::Response,
        success?: false,
        errors: ActiveModel::Errors.new(statement_file).tap { |e| e.add(:base, "boom") }
      )
      allow(Statements::VisionExtractor).to receive(:call).and_return(failed)

      expect(described_class.call(statement_file)).to be_failure
    end
  end

  describe "category rules" do
    let(:parent_category) { create(:category, user: user, name: "Deudas y Prestamos") }
    let(:child_category) do
      create(:category, user: user, name: "Credito Automotriz", parent: parent_category)
    end
    let(:ai_category) { create(:category, user: user, name: "Prestamos Personales") }

    let(:extracted) do
      {
        "transactions" => [
          {
            "date" => "2026-06-19",
            "description" => "PAGO DE PRESTAMO 9837815631 TOTAL DE RECIBO",
            "amount" => "-13975.23",
            "transaction_type" => "variable_expense",
            "category_id" => ai_category.id
          }
        ]
      }
    end

    before do
      allow(Statements::VisionExtractor).to receive(:call).and_return(
        ApplicationService::Response.new(success: true, payload: extracted, errors: nil)
      )
    end

    # The vision path does extraction and categorization in one AI call and never
    # consulted the user's rules, so every correction they had taught was ignored
    # on the strategy that is the default for new accounts.
    it "overrides the AI's category with a matching rule" do
      create(
        :category_rule, user: user, category: child_category,
        pattern: "pago de prestamo total de recibo", match_type: "contains"
      )

      described_class.call(statement_file)

      expect(statement_file.transactions.sole.category_id).to eq(child_category.id)
    end

    it "leaves the AI's category alone when no rule matches" do
      create(
        :category_rule, user: user, category: child_category,
        pattern: "compra en reporto", match_type: "contains"
      )

      described_class.call(statement_file)

      expect(statement_file.transactions.sole.category_id).to eq(ai_category.id)
    end

    it "counts the hit against the rule" do
      rule = create(
        :category_rule, user: user, category: child_category,
        pattern: "pago de prestamo total de recibo", match_type: "contains"
      )

      expect { described_class.call(statement_file) }
        .to change { rule.reload.hits_count }.by(1)
    end
  end
end
