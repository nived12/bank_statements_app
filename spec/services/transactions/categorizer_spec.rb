# spec/services/transactions/categorizer_spec.rb
require "rails_helper"

RSpec.describe Transactions::Categorizer do
  let(:user) { create(:user) }
  let(:category_income) { create(:category, name: "Ingresos", user: user, parent: nil) }
  let(:category_expenses) { create(:category, name: "Compras", user: user, parent: nil) }
  let(:subcategory_groceries) { create(:category, name: "Supermercado", user: user, parent: category_expenses) }

  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:ai_client) { instance_double(Ai::Client) }

  let(:data) do
    {
      transactions: [
        {
          "date" => "2024-01-15",
          "description" => "OXXO Purchase",
          "amount" => -50.00
        },
        {
          "date" => "2024-01-16",
          "description" => "Salary Deposit",
          "amount" => 5000.00
        }
      ]
    }
  end

  before do
    # Create categories for the user
    category_income
    category_expenses
    subcategory_groceries

    allow(Ai::Client).to receive(:new).and_return(ai_client)
  end

  describe "#call" do
    let(:ai_response) do
      # AI now returns IDs directly instead of names
      response_data = {
        "transactions" => [
          {
            "date" => "2024-01-15",
            "description" => "OXXO Purchase",
            "amount" => -50.00,
            "category_id" => category_expenses.id,
            "sub_category_id" => subcategory_groceries.id,
            "merchant" => "OXXO",
            "transaction_type" => "variable_expense",
            "confidence" => 0.85,
            "category_confidence" => 0.90,
            "transaction_type_confidence" => 0.80
          },
          {
            "date" => "2024-01-16",
            "description" => "Salary Deposit",
            "amount" => 5000.00,
            "category_id" => category_income.id,
            "merchant" => "Employer",
            "transaction_type" => "income",
            "confidence" => 0.95,
            "category_confidence" => 0.98,
            "transaction_type_confidence" => 0.92
          }
        ]
      }
      response_data.to_json
    end

    before do
      allow(ai_client).to receive(:chat).and_return(
        {
                text: ai_response,
                usage: {
                  prompt_token_count: 500,
                  candidates_token_count: 250,
                  total_token_count: 750
                }
              }
      )
    end

    it "categorizes transactions using AI" do
      result = described_class.call(statement_file, data)

      expect(result).to be_success
      expect(result.payload[:transactions].count).to eq(2)
    end

    it "resolves category names to IDs" do
      result = described_class.call(statement_file, data)

      first_transaction = result.payload[:transactions].first
      expect(first_transaction["category_id"]).to eq(category_expenses.id)
      expect(first_transaction["sub_category_id"]).to eq(subcategory_groceries.id)
    end

    it "adds merchant and transaction type" do
      result = described_class.call(statement_file, data)

      first_transaction = result.payload[:transactions].first
      expect(first_transaction["merchant"]).to eq("OXXO")
      expect(first_transaction["transaction_type"]).to eq("variable_expense")
    end

    it "adds confidence scores" do
      result = described_class.call(statement_file, data)

      first_transaction = result.payload[:transactions].first
      expect(first_transaction["confidence"]).to eq(0.85)
      expect(first_transaction["category_confidence"]).to eq(0.90)
      expect(first_transaction["transaction_type_confidence"]).to eq(0.80)
    end

    context "when AI returns empty response" do
      before do
        allow(ai_client).to receive(:chat).and_return({ text: nil, usage: {} })
      end

      it "returns original transactions" do
        result = described_class.call(statement_file, data)

        expect(result).to be_success
        expect(result.payload[:transactions]).to eq(data[:transactions])
      end
    end

    context "when AI returns invalid JSON" do
      before do
        allow(ai_client).to receive(:chat).and_return({ text: "Invalid JSON {", usage: {} })
      end

      it "returns original transactions" do
        result = described_class.call(statement_file, data)

        expect(result).to be_success
        expect(result.payload[:transactions]).to eq(data[:transactions])
      end
    end

    context "when AI categorization fails with exception" do
      before do
        allow(ai_client).to receive(:chat).and_raise(StandardError, "API timeout")
      end

      it "returns original data gracefully" do
        result = described_class.call(statement_file, data)

        expect(result).to be_success
        expect(result.payload).to eq(data)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/categorization failed/)

        described_class.call(statement_file, data)
      end
    end

    context "with more than 25 transactions" do
      let(:many_transactions) do
        {
          transactions: (1..30).map do |i|
            {
              "date" => "2024-01-#{i.to_s.rjust(2, "0")}",
              "description" => "Transaction #{i}",
              "amount" => -100.00
            }
          end
        }
      end

      it "processes in batches" do
        expect(ai_client).to receive(:chat).twice

        described_class.call(statement_file, many_transactions)
      end

      it "logs batch progress" do
        expect(Rails.logger).to receive(:info).with(/batch 1\/2/).at_least(:once)
        expect(Rails.logger).to receive(:info).with(/batch 2\/2/).at_least(:once)
        allow(Rails.logger).to receive(:info) # Allow other info logs

        described_class.call(statement_file, many_transactions)
      end
    end

    context "when data has no transactions" do
      let(:empty_data) { { transactions: [] } }

      it "returns data unchanged" do
        result = described_class.call(statement_file, empty_data)

        expect(result).to be_success
        expect(result.payload).to eq(empty_data)
      end

      it "does not call AI" do
        expect(ai_client).not_to receive(:chat)

        described_class.call(statement_file, empty_data)
      end
    end
  end
end
