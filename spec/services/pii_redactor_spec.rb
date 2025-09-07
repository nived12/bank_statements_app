# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiiRedactor do
  let(:svc) { described_class.new(secret: "test-secret") }

  let(:input) do
    <<~TEXT
      Cliente: Carlos Rodriguez
      Email: carlos.rodriguez@example.com
      Tel: +52 (81) 9876-5432
      CLABE: 002 010 700 987654321
      Tarjeta: 9876 5432 1098 7654
      RFC: RODC987654321
      CURP: RODC987654DEF321GHI
      Dirección: Av. Reforma 456, Col. Norte, CP 54321
    TEXT
  end

  describe "basic PII redaction" do
    let(:redacted_result) { svc.redact(input) }
    let(:redacted) { redacted_result[0] }
    let(:map) { redacted_result[1] }
    let(:hmac) { redacted_result[2] }

    it "redacts and restores typical PII and computes HMAC" do
      expect(map).not_to be_empty
      expect(redacted).to include("⟪PII:")

      restored = svc.restore(redacted, map)
      expect(restored).to eq(input)
    end

    it "redacts email addresses" do
      expect(redacted).not_to include("carlos.rodriguez@example.com")
    end

    it "redacts phone numbers" do
      expect(redacted).not_to include("9876-5432")
    end

    it "redacts CLABE numbers" do
      expect(redacted).not_to include("002 010 700 987654321")
    end

    it "redacts card numbers" do
      expect(redacted).not_to include("9876 5432 1098 7654")
    end

    it "redacts RFC numbers" do
      expect(redacted).not_to include("RODC987654321")
    end

    it "redacts CURP numbers" do
      expect(redacted).not_to include("RODC987654DEF321GHI")
    end
  end
end
