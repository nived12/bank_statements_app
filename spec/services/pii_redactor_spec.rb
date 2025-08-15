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

  let(:bank_statement_input) do
    <<~TEXT
      No. de Cliente: 12345678
      No. de Cuenta: 98765432109
      Telefono: 5551234567
      PLAZA MAYOR MEXICO
      Referencia: XYZ789ABC123
      Numero Grande: 987654321098765432109876543210

      Detalle de Movimientos:
      15/JUN R01 PAGO DE NOMINA 12,500.00
      Ref: 98765432109876543210
      C19 INTERESES GANADOS 5.50
      T16 SPEI ENVIADO BANCO 25,000.00
      REF:98765XYZ123456789
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
      expect(svc.valid_hmac?(redacted, hmac)).to eq(true)

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

  describe "#redact_preserving_transactions" do
    let(:transaction_result) { svc.redact_preserving_transactions(bank_statement_input) }
    let(:redacted) { transaction_result[0] }
    let(:map) { transaction_result[1] }
    let(:hmac) { transaction_result[2] }

    it "redacts PII while preserving transaction data for AI categorization" do
      expect(redacted).to include("⟪PII:")
      expect(redacted).to include("PAGO DE NOMINA 12,500.00")
      expect(redacted).to include("INTERESES GANADOS 5.50")
      expect(redacted).to include("SPEI ENVIADO BANCO 25,000.00")
      expect(redacted).to include("R01")
      expect(redacted).to include("C19")
      expect(redacted).to include("T16")
      expect(svc.valid_hmac?(redacted, hmac)).to eq(true)
    end

    it "redacts client numbers" do
      expect(redacted).not_to include("12345678")
    end

    it "redacts account numbers" do
      expect(redacted).not_to include("98765432109")
    end

    it "redacts phone numbers" do
      expect(redacted).not_to include("5551234567")
    end

    it "redacts addresses" do
      expect(redacted).not_to include("PLAZA MAYOR MEXICO")
    end

    it "redacts reference numbers" do
      expect(redacted).not_to include("XYZ789ABC123")
    end

    it "redacts large numbers" do
      expect(redacted).not_to include("987654321098765432109876543210")
    end

    it "redacts transaction reference numbers" do
      expect(redacted).not_to include("98765432109876543210")
    end

    it "redacts prefixed IDs" do
      expect(redacted).not_to include("REF:98765XYZ123456789")
    end

    it "preserves transaction codes" do
      expect(redacted).to include("R01")
      expect(redacted).to include("C19")
      expect(redacted).to include("T16")
    end

    it "does not redact transaction descriptions with spaces and prepositions" do
      test_text = "24/MAY W02 DEPOSITO DE TERCERO 3,778.00\n15/JUN R01 PAGO DE NOMINA 12,500.00\nC19 INTERESES GANADOS 5.50\nT16 SPEI ENVIADO BANCO 25,000.00"
      redacted, _map, _hmac = svc.redact_preserving_transactions(test_text)

      # Transaction descriptions should NOT be redacted
      expect(redacted).to include("DEPOSITO DE TERCERO")
      expect(redacted).to include("PAGO DE NOMINA")
      expect(redacted).to include("INTERESES GANADOS")
      expect(redacted).to include("SPEI ENVIADO BANCO")
      expect(redacted).not_to include("⟪PII:")
    end

    it "maintains proper redaction map structure" do
      expect(map).to be_a(Hash)
      expect(map.keys).to all(match(/⟪PII:[A-Z_]+:\d+⟫/))
      expect(map.values).to all(be_a(String))
    end

    it "can restore PII while keeping transaction data intact" do
      restored = svc.restore(redacted, map)

      expect(restored).to include("12345678")
      expect(restored).to include("98765432109")
      expect(restored).to include("5551234567")
      expect(restored).to include("PLAZA MAYOR MEXICO")
      expect(restored).to include("XYZ789ABC123")
      expect(restored).to include("987654321098765432109876543210")
      expect(restored).to include("98765432109876543210")
      expect(restored).to include("REF:98765XYZ123456789")
      expect(restored).to include("PAGO DE NOMINA 12,500.00")
      expect(restored).to include("R01")
    end
  end
end
