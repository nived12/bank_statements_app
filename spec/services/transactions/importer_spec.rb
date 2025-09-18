require 'rails_helper'

RSpec.describe Transactions::Importer do
  let(:user) { create(:user) }
  let(:bank) { create(:bank) }
  let(:bank_account) { create(:bank_account, user: user, bank: bank) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }

  let!(:food_category) { user.categories.create!(name: "Comida") }
  let!(:restaurant_category) { user.categories.create!(name: "Restaurantes", parent: food_category) }
  let!(:uncategorized) { user.categories.create!(name: "Sin Categorizar") }

  describe '.call' do
    let(:valid_json) do
      {
        "transactions" => [
          {
            "date" => "2024-03-15",
            "description" => "Restaurant payment",
            "amount" => "-25.50",
            "transaction_type" => "variable_expense",
            "bank_entry_type" => "debit",
            "category_id" => food_category.id,
            "sub_category_id" => restaurant_category.id,
            "merchant" => "Test Restaurant",
            "reference" => "REF123"
          },
          {
            "date" => "2024-03-16",
            "description" => "Salary deposit",
            "amount" => "2500.00",
            "transaction_type" => "income",
            "bank_entry_type" => "credit",
            "category_id" => food_category.id,
            "sub_category_id" => nil,
            "merchant" => nil,
            "reference" => "PAY456"
          }
        ]
      }
    end

    context 'with valid JSON data' do
      it 'creates transactions from JSON data' do
        expect {
          described_class.call(statement_file, json: valid_json)
        }.to change { Transaction.count }.by(2)
      end

      it 'returns a success response' do
        result = described_class.call(statement_file, json: valid_json)
        expect(result.success?).to be true
        expect(result.payload).to be_nil
      end

      it 'creates transactions with correct attributes' do
        described_class.call(statement_file, json: valid_json)

        restaurant_transaction = Transaction.find_by(description: "Restaurant payment")
        expect(restaurant_transaction.user_id).to eq(user.id)
        expect(restaurant_transaction.bank_account_id).to eq(bank_account.id)
        expect(restaurant_transaction.statement_file_id).to eq(statement_file.id)
        expect(restaurant_transaction.date).to eq(Date.parse("2024-03-15"))
        expect(restaurant_transaction.description).to eq("Restaurant payment")
        expect(restaurant_transaction.amount).to eq(BigDecimal("-25.50"))
        expect(restaurant_transaction.transaction_type).to eq("variable_expense")
        expect(restaurant_transaction.bank_entry_type).to eq("debit")
        expect(restaurant_transaction.category_id).to eq(restaurant_category.id)
        expect(restaurant_transaction.merchant).to eq("Test Restaurant")
        expect(restaurant_transaction.reference).to eq("REF123")
      end

      it 'resolves categories correctly' do
        described_class.call(statement_file, json: valid_json)

        restaurant_transaction = Transaction.find_by(description: "Restaurant payment")
        expect(restaurant_transaction.category_id).to eq(restaurant_category.id)
        expect(restaurant_transaction.category.parent.name).to eq("Comida")
      end
    end

    context 'with statement file containing parsed_json' do
      before do
        statement_file.update!(parsed_json: valid_json)
      end

      it 'uses parsed_json from statement file when json not provided' do
        expect {
          described_class.call(statement_file)
        }.to change { Transaction.count }.by(2)
      end
    end

    context 'with invalid or missing data' do
      it 'returns failure when json is nil' do
        result = described_class.call(statement_file, json: nil)
        expect(result.success?).to be false
      end

      it 'returns failure when json is not a hash' do
        result = described_class.call(statement_file, json: "invalid")
        expect(result.success?).to be false
      end

      it 'returns failure when transactions array is missing' do
        result = described_class.call(statement_file, json: { "other_data" => [] })
        expect(result.success?).to be false
      end

      it 'returns failure when transactions is not an array' do
        result = described_class.call(statement_file, json: { "transactions" => "invalid" })
        expect(result.success?).to be false
      end
    end

    context 'category resolution' do
      it 'finds existing parent category when subcategory is empty' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "Food purchase",
            "amount" => "-15.00",
            "category_id" => food_category.id,
            "sub_category_id" => nil
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.category_id).to eq(food_category.id)
      end

      it 'finds existing subcategory when both category and subcategory exist' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "Restaurant meal",
            "amount" => "-25.00",
            "category_id" => food_category.id,
            "sub_category_id" => restaurant_category.id
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.category.name).to eq("Restaurantes")
      end

      it 'falls back to uncategorized when category not found' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "Unknown purchase",
            "amount" => "-10.00",
            "category_id" => nil,
            "sub_category_id" => nil
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.category_id).to eq(uncategorized.id)
      end

      it 'handles nil category gracefully' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "No category",
            "amount" => "-5.00",
            "category_id" => nil,
            "sub_category_id" => nil
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.category.name).to eq("Sin Categorizar")
      end
    end

    context 'amount handling' do
      it 'converts string amounts to decimal' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "String amount",
            "amount" => "-1,234.56"
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.amount).to eq(BigDecimal("-1234.56"))
      end

      it 'handles numeric amounts' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "Numeric amount",
            "amount" => 100.25
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.amount).to eq(BigDecimal("100.25"))
      end
    end

    context 'transaction type normalization' do
      it 'preserves valid transaction types' do
        %w[income fixed_expense variable_expense].each do |type|
          json = {
            "transactions" => [ {
              "date" => "2024-03-15",
              "description" => "Test transaction",
              "amount" => "100.00",
              "transaction_type" => type
            } ]
          }

          described_class.call(statement_file, json: json)
          transaction = Transaction.last
          expect(transaction.transaction_type).to eq(type)
        end
      end

      it 'infers transaction type from amount when invalid type provided' do
        # Negative amount should be variable_expense
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "Expense",
            "amount" => "-50.00",
            "transaction_type" => "invalid_type"
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.transaction_type).to eq("variable_expense")
      end

      it 'defaults positive amounts to income when type is invalid' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "Income",
            "amount" => "100.00",
            "transaction_type" => "invalid_type"
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.transaction_type).to eq("income")
      end
    end

    context 'bank entry type normalization' do
      it 'normalizes credit variations' do
        %w[credit cr].each do |type|
          json = {
            "transactions" => [ {
              "date" => "2024-03-15",
              "description" => "Credit test",
              "amount" => "100.00",
              "bank_entry_type" => type
            } ]
          }

          described_class.call(statement_file, json: json)
          transaction = Transaction.last
          expect(transaction.bank_entry_type).to eq("credit")
        end
      end

      it 'normalizes debit variations' do
        %w[debit dr].each do |type|
          json = {
            "transactions" => [ {
              "date" => "2024-03-15",
              "description" => "Debit test",
              "amount" => "-50.00",
              "bank_entry_type" => type
            } ]
          }

          described_class.call(statement_file, json: json)
          transaction = Transaction.last
          expect(transaction.bank_entry_type).to eq("debit")
        end
      end

      it 'returns nil for unrecognized bank entry types' do
        json = {
          "transactions" => [ {
            "date" => "2024-03-15",
            "description" => "Unknown type",
            "amount" => "100.00",
            "bank_entry_type" => "unknown"
          } ]
        }

        described_class.call(statement_file, json: json)
        transaction = Transaction.last
        expect(transaction.bank_entry_type).to be_nil
      end
    end

        context 'error handling' do
      it 'raises error when date parsing fails' do
        json = {
          "transactions" => [ {
            "date" => "invalid-date",
            "description" => "Bad transaction",
            "amount" => "100.00"
          } ]
        }

        expect {
          described_class.call(statement_file, json: json)
        }.to raise_error(Date::Error)
      end
    end
  end
end
