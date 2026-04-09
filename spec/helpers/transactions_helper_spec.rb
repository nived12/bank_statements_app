require "rails_helper"

RSpec.describe TransactionsHelper, type: :helper do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }

  describe "#display_concept" do
    it "returns concept when present" do
      tx = build(
        :transaction, user: user, bank_account: bank_account,
        description: "PAGO CUENTA DE TERCERO BNET 1234 servicio jardineria",
        concept: "PAGO CUENTA DE TERCERO servicio jardineria"
      )
      expect(helper.display_concept(tx)).to eq("PAGO CUENTA DE TERCERO servicio jardineria")
    end

    it "falls back to short_description when concept is blank" do
      tx = build(
        :transaction, user: user, bank_account: bank_account,
        description: "Netflix",
        concept: nil
      )
      expect(helper.display_concept(tx)).to eq("Netflix")
    end

    it "falls back to short_description when concept is empty string" do
      tx = build(
        :transaction, user: user, bank_account: bank_account,
        description: "Netflix",
        concept: ""
      )
      expect(helper.display_concept(tx)).to eq("Netflix")
    end
  end
end
