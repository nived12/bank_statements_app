require "rails_helper"

RSpec.describe Ai::PostProcessor do
  let(:client) do
    instance_double(
      Ai::Client,
      chat: <<~JSON
        {
          "opening_balance": 12000.50,
          "closing_balance": 9850.75,
          "transactions": [
            {
              "date": "2025-01-03",
              "description": "Pago Nomina EMPRESA SA",
              "amount": 15000.00,
              "type": "income",
              "bank_entry_type": "credit",
              "merchant": null,
              "reference": "REF123",
              "category": "Ingreso",
              "sub_category": "Sueldo",
              "fixed_or_variable": "variable",
              "raw_text": "03/01/2025 Pago Nomina EMPRESA SA 15,000.00",
              "confidence": 0.92
            },
            {
              "date": "2025-01-05",
              "description": "Amazon Marketplace",
              "amount": -1299.99,
              "type": "expense",
              "bank_entry_type": "debit",
              "merchant": "Amazon",
              "reference": null,
              "category": "Uncategorized",
              "sub_category": null,
              "fixed_or_variable": "variable",
              "raw_text": "05/01/2025 Amazon Marketplace -1,299.99",
              "confidence": 0.75
            }
          ]
        }
      JSON
    )
  end

  let(:svc) { described_class.new(client: client) }
  let(:result) do
    svc.call(
      raw_text: "03/01/2025 Pago Nomina EMPRESA SA 15,000.00\n05/01/2025 Amazon Marketplace -1,299.99",
      bank_name: "BBVA",
      account_number: "1234"
    )
  end

  it "returns transactions with income/expense type and bank_entry_type" do
    expect(result["transactions"].size).to eq(2)

    first = result["transactions"].first
    expect(first["type"]).to eq("income")
    expect(first["bank_entry_type"]).to eq("credit")
    expect(first["amount"]).to eq(15000.0)

    second = result["transactions"][1]
    expect(second["type"]).to eq("expense")
    expect(second["bank_entry_type"]).to eq("debit")
    expect(second["amount"]).to eq(-1299.99)
  end
end
