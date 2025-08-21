require "rails_helper"

RSpec.describe Ai::PostProcessor do
  let(:user) { create(:user) }
  let(:client) do
    instance_double(
      Ai::Client,
      chat: <<~JSON.strip
        {
          "opening_balance": 12000.50,
          "closing_balance": 9850.75,
          "transactions": [
            {
              "date": "2025-01-03",
              "description": "Pago Nomina EMPRESA SA",
              "amount": 15000.00,
              "transaction_type": "income",
              "bank_entry_type": "credit",
              "merchant": null,
              "reference": "REF123",
              "category": "Uncategorized",
              "sub_category": null,
              "raw_text": "03/01/2025 Pago Nomina EMPRESA SA 15,000.00",
              "confidence": 0.92
            },
            {
              "date": "2025-01-05",
              "description": "Amazon Marketplace",
              "amount": -1299.99,
              "transaction_type": "variable_expense",
              "bank_entry_type": "debit",
              "merchant": "Amazon",
              "reference": null,
              "category": "Uncategorized",
              "sub_category": null,
              "raw_text": "05/01/2025 Amazon Marketplace -1,299.99",
              "confidence": 0.75
            }
          ]
        }
      JSON
    )
  end

  let(:categories) { Category.where(id: create_list(:category, 3, user: user).map(&:id)) }
  let(:svc) { described_class.new(client: client) }

  it "returns transactions with transaction_type and bank_entry_type" do
    result = svc.call(
      raw_text: "PAGO DE NOMINA IN 4206032877 EMPRESA SA\nSPEI ENVIADO Amazon Marketplace 1299.99",
      bank_name: "BBVA",
      account_number: "1234",
      categories: categories
    )

    expect(result["transactions"].size).to eq(2)
    first = result["transactions"].first
    expect(first["transaction_type"]).to eq("income")
    expect(first["bank_entry_type"]).to eq("credit")

    second = result["transactions"][1]
    expect(second["transaction_type"]).to eq("variable_expense")
    expect(second["bank_entry_type"]).to eq("debit")
  end

  it "correctly validates Spanish banking terms IMPORTE CARGOS and IMPORTE ABONOS" do
    # Test case where AI incorrectly parsed CARGOS as positive (should be negative)
    client_with_spanish_terms = instance_double(
      Ai::Client,
      chat: <<~JSON.strip
        {
          "opening_balance": 0.0,
          "closing_balance": 0.0,
          "transactions": [
            {
              "date": "2024-02-17",
              "description": "SPEI ENVIADO 300843361 SIX PREMIER",
              "amount": -385.00,
              "transaction_type": "variable_expense",
              "bank_entry_type": "debit",
              "merchant": "SIX PREMIER",
              "reference": "300843361",
              "category": "Entretenimiento",
              "sub_category": "Hobbies",
              "raw_text": "SPEI ENVIADO 300843361 SIX PREMIER",
              "confidence": 0.95
            },
            {
              "date": "2024-01-21",
              "description": "PAGO INTERBANCARIO BMOVIL.PAGO TDC",
              "amount": 3111.81,
              "transaction_type": "income",
              "bank_entry_type": "credit",
              "merchant": "BMOVIL",
              "reference": null,
              "category": "Ingresos",
              "sub_category": "Pago",
              "raw_text": "PAGO INTERBANCARIO BMOVIL.PAGO TDC",
              "confidence": 0.95
            }
          ]
        }
      JSON
    )

    svc_with_spanish = described_class.new(client: client_with_spanish_terms)
    result = svc_with_spanish.call(
      raw_text: "SPEI ENVIADO 300843361 SIX PREMIER\nPAGO INTERBANCARIO BMOVIL.PAGO TDC",
      bank_name: "BBVA",
      account_number: "1234",
      categories: categories
    )

    expect(result["transactions"].size).to eq(2)

    # First transaction - SPEI ENVIADO (should be negative expense)
    first = result["transactions"].first
    expect(first["amount"]).to eq(-385.00)
    expect(first["transaction_type"]).to eq("variable_expense")
    expect(first["bank_entry_type"]).to eq("debit")

    # Second transaction - PAGO INTERBANCARIO (should be positive income)
    second = result["transactions"][1]
    expect(second["amount"]).to eq(3111.81)
    expect(second["transaction_type"]).to eq("income")
    expect(second["bank_entry_type"]).to eq("credit")
  end
end
