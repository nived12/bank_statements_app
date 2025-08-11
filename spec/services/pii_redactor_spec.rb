# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiiRedactor do
  let(:svc) { described_class.new(secret: "test-secret") }
  let(:input) do
    <<~TEXT
      Cliente: Juan Pérez
      Email: juan.perez@example.com
      Tel: +52 (81) 1234-5678
      CLABE: 002 010 700 123456789
      Tarjeta: 4111 1111 1111 1111
      RFC: PEJJ800101ABC
      CURP: PEXX800101HDFRRN08
      Dirección: Av. Lázaro Cárdenas 1000, Col. Valle, CP 66220
    TEXT
  end

  it "redacts and restores typical PII and computes HMAC" do
    redacted, map, hmac = svc.redact(input)

    expect(map).not_to be_empty
    expect(redacted).to include("⟪PII:EMAIL:1⟫")
    expect(redacted).to include("⟪PII:PHONE:1⟫")
    expect(redacted).to include("⟪PII:CLABE:1⟫")
    expect(redacted).to include("⟪PII:CARD:1⟫")
    expect(redacted).to include("⟪PII:RFC:1⟫")
    expect(redacted).to include("⟪PII:CURP:1⟫")
    expect(redacted).to include("⟪PII:ADDR:1⟫")

    expect(svc.valid_hmac?(redacted, hmac)).to eq(true)

    restored = svc.restore(redacted, map)
    expect(restored).to eq(input)
  end
end
