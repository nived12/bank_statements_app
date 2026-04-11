require "rails_helper"

RSpec.describe Belvo::InstitutionMapper do
  describe ".call" do
    context "when institution maps to existing bank" do
      let!(:bank) { Bank.find_by(code: "bbva") || create(:bank, code: "bbva", name: "BBVA") }

      it "returns the mapped bank" do
        result = described_class.call("bbva_mx_retail")
        expect(result).to be_success
        expect(result.payload).to eq(bank)
      end
    end

    context "when institution is not in map" do
      it "creates a new bank from the institution code" do
        result = described_class.call("unknown_mx_retail")
        expect(result).to be_success
        expect(result.payload.code).to eq("unknown_mx_retail")
        expect(result.payload.active).to be true
      end
    end

    context "when mapped institution has no local bank" do
      it "falls back to creating with the institution code" do
        # Remove any existing banregio bank so the mapper has to create
        Bank.where(code: "banregio").destroy_all
        result = described_class.call("banregio_mx_retail")
        expect(result).to be_success
        expect(result.payload.code).to eq("banregio_mx_retail")
      end
    end
  end
end
