require "rails_helper"

RSpec.describe PdfParser::Generic do
  let(:text) do
    <<~TXT
      03/01/2025 Pago Nomina EMPRESA SA 15,000.00
      05/01/2025 Amazon Marketplace -1,299.99
      Not a transaction line
      07-01-2025 OXXO Compra -89.00
    TXT
  end

  let(:parser) { described_class.new }
  let(:result) { parser.parse(text) }

  it "extracts transactions with transaction_type and bank_entry_type" do
    expect(result["transactions"].size).to eq(3)

    first = result["transactions"].first
    expect(first["date"]).to eq("2025-01-03")
    expect(first["description"]).to include("Pago Nomina EMPRESA SA")
    expect(first["amount"]).to eq(15000.0)
    expect(first["transaction_type"]).to eq("income")
    expect(first["bank_entry_type"]).to eq("credit")

    third = result["transactions"][2]
    expect(third["date"]).to eq("2025-01-07")
    expect(third["description"]).to include("OXXO Compra")
    expect(third["amount"]).to eq(-89.0)
    expect(third["transaction_type"]).to eq("variable_expense")
    expect(third["bank_entry_type"]).to eq("debit")
  end
end
