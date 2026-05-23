# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::SubjectTracker do
  let(:user) { create(:user) }
  let(:conversation) { create(:assistant_conversation, user: user, locale: "es-MX") }

  def run(intent:, tools_called: [], slots: {}, suggestion_key: nil)
    described_class.new(
      conversation: conversation,
      intent: intent,
      tools_called: tools_called,
      slots: slots,
      suggestion_key: suggestion_key
    ).call
    conversation.reload.last_subject
  end

  describe "tool-derived subjects" do
    it "writes category subject from query_transactions(category_name)" do
      tools = [{ "name" => "query_transactions",
                 "args" => { "category_name" => "Compras",
                             "date_from" => "2026-05-01",
                             "date_to" => "2026-05-31" } }]
      subject = run(intent: :llm_freeform, tools_called: tools)
      expect(subject).to eq({ "type" => "category", "name" => "Compras", "period" => "2026-05" })
    end

    it "writes account subject from query_transactions(account_name)" do
      tools = [{ "name" => "query_transactions",
                 "args" => { "account_name" => "Banorte" } }]
      subject = run(intent: :llm_freeform, tools_called: tools)
      expect(subject["type"]).to eq("account")
      expect(subject["name"]).to eq("Banorte")
    end

    it "writes debt subject when debt_name present" do
      tools = [{ "name" => "get_debts", "args" => { "debt_name" => "BBVA" } }]
      expect(run(intent: :llm_freeform, tools_called: tools))
        .to eq({ "type" => "debt", "name" => "BBVA" })
    end

    it "writes overview subject when no specific name given" do
      tools = [{ "name" => "get_debts", "args" => {} }]
      expect(run(intent: :llm_freeform, tools_called: tools))
        .to eq({ "type" => "debts_overview" })
    end
  end

  describe "suggestion-derived subjects" do
    it "monthly_breakdown → period subject for current month" do
      subject = run(intent: :suggestion_monthly_breakdown, suggestion_key: "monthly_breakdown")
      expect(subject["type"]).to eq("period")
      expect(subject["period"]).to eq(Date.current.strftime("%Y-%m"))
    end

    it "savings_overview → savings_overview subject" do
      subject = run(intent: :suggestion_savings_overview, suggestion_key: "savings_overview")
      expect(subject).to eq({ "type" => "savings_overview" })
    end
  end

  describe "preserve-existing behavior" do
    before do
      conversation.update_column(:last_subject, { "type" => "category", "name" => "Comida" })
    end

    it "does not overwrite on greeting intents" do
      subject = run(intent: :greeting, tools_called: [])
      expect(subject).to eq({ "type" => "category", "name" => "Comida" })
    end

    it "does not overwrite on off_topic" do
      subject = run(intent: :off_topic, tools_called: [])
      expect(subject).to eq({ "type" => "category", "name" => "Comida" })
    end

    it "does not overwrite when no tool was called and intent is llm_freeform" do
      subject = run(intent: :llm_freeform, tools_called: [])
      expect(subject).to eq({ "type" => "category", "name" => "Comida" })
    end
  end

  describe "shape compatibility" do
    it "handles legacy string-only tools_called entries" do
      subject = run(intent: :llm_freeform, tools_called: ["get_net_worth"])
      expect(subject["type"]).to eq("net_worth")
    end
  end
end
