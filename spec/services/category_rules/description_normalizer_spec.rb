require "rails_helper"

RSpec.describe CategoryRules::DescriptionNormalizer do
  describe ".call" do
    it "downcases the description" do
      expect(described_class.call("STARBUCKS COFFEE")).to eq("starbucks coffee")
    end

    it "strips leading and trailing whitespace" do
      expect(described_class.call("  starbucks  ")).to eq("starbucks")
    end

    it "collapses multiple spaces into one" do
      expect(described_class.call("starbucks   coffee   shop")).to eq("starbucks coffee shop")
    end

    it "strips trailing long numbers (references)" do
      expect(described_class.call("PAGO TARJETA 000123456789")).to eq("pago tarjeta")
    end

    it "strips trailing hash references" do
      expect(described_class.call("Transfer #REF123456")).to eq("transfer")
    end

    it "handles combined normalizations" do
      expect(described_class.call("  NETFLIX  SUBSCRIPTION  #ABC123  ")).to eq("netflix subscription")
    end

    it "returns empty string for nil" do
      expect(described_class.call(nil)).to eq("")
    end

    it "returns empty string for blank" do
      expect(described_class.call("")).to eq("")
      expect(described_class.call("   ")).to eq("")
    end

    it "preserves short trailing numbers (3 or fewer digits)" do
      expect(described_class.call("uber eats 123")).to eq("uber eats 123")
    end

    it "strips trailing numbers of 4+ digits" do
      expect(described_class.call("uber eats 1234")).to eq("uber eats")
    end
  end
end
