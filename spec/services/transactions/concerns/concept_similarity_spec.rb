require "rails_helper"

RSpec.describe Transactions::Concerns::ConceptSimilarity do
  # Build a minimal host object that exposes the private methods for testing
  let(:host_class) do
    Class.new do
      include Transactions::Concerns::ConceptSimilarity
      public :calculate_similarity, :normalize_text
    end
  end

  subject { host_class.new }

  describe "#calculate_similarity" do
    it "returns 1.0 for identical strings" do
      expect(subject.calculate_similarity("Test Transaction", "Test Transaction")).to eq(1.0)
    end

    it "returns 0.0 for completely different strings" do
      expect(subject.calculate_similarity("Test Transaction", "Completely Different")).to eq(0.0)
    end

    it "returns a score > 0.5 for partially similar strings" do
      score = subject.calculate_similarity("Test Transaction Walmart", "Test Transaction at Walmart")
      expect(score).to be > 0.5
    end

    it "returns 0.0 for a blank first argument" do
      expect(subject.calculate_similarity("", "Test Transaction")).to eq(0.0)
    end

    it "returns 0.0 for a blank second argument" do
      expect(subject.calculate_similarity("Test Transaction", "")).to eq(0.0)
    end
  end

  describe "#normalize_text" do
    it "converts to lowercase" do
      expect(subject.normalize_text("TEST TRANSACTION")).to eq("test transaction")
    end

    it "removes punctuation" do
      expect(subject.normalize_text("Test, Transaction!")).to eq("test transaction")
    end

    it "normalizes whitespace" do
      expect(subject.normalize_text("Test   Transaction")).to eq("test transaction")
    end
  end

  describe "#concept_similar_enough?" do
    let(:existing) do
      build_stubbed(
        :transaction,
        description: "mueble pecera",
        concept: "mueble pecera"
      )
    end

    it "matches via concept when raw description similarity is too low" do
      incoming = {
        "description" => "SPEI ENVIADO BANORTE 0097161491 072 1803260mueble pecera MBAN Oscar Amaro",
        "concept" => "SPEI ENVIADO mueble pecera Oscar Amaro"
      }
      expect(subject.concept_similar_enough?(incoming, existing)).to be true
    end

    it "does not match when concept is unrelated" do
      incoming = {
        "description" => "SPEI ENVIADO BANORTE 0097161491 compra completamente diferente",
        "concept" => "SPEI ENVIADO compra completamente diferente"
      }
      expect(subject.concept_similar_enough?(incoming, existing)).to be false
    end

    it "falls back to description comparison when concept is blank" do
      incoming = { "description" => "mueble pecera", "concept" => "" }
      expect(subject.concept_similar_enough?(incoming, existing)).to be true
    end

    it "returns false for blank incoming description and no concept" do
      incoming = { "description" => "", "concept" => nil }
      expect(subject.concept_similar_enough?(incoming, existing)).to be false
    end
  end
end
