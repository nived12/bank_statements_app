require 'rails_helper'

RSpec.describe Transactions::DuplicateDetector, type: :service do
  let(:user) { create(:user) }
  let(:bank_account) { create(:bank_account, user: user) }
  let(:statement_file) { create(:statement_file, user: user, bank_account: bank_account) }
  let(:service) { described_class.new(statement_file) }

  describe '#call' do
    context 'when there are no transactions in parsed_json' do
      before do
        statement_file.update(parsed_json: { "transactions" => [] })
      end

      it 'returns success with empty array' do
        result = service.call
        expect(result.success?).to be true
        expect(result.payload).to eq([])
      end
    end

    context 'when parsed_json is not a hash' do
      before do
        statement_file.update(parsed_json: "invalid")
      end

      it 'returns success with empty array' do
        result = service.call
        expect(result.success?).to be true
        expect(result.payload).to eq([])
      end
    end

    context 'when there are exact duplicates' do
      let(:transaction_data) do
        {
          "date" => "2024-01-15",
          "description" => "Test Transaction",
          "amount" => "100.00",
          "transaction_type" => "income"
        }
      end

      before do
        # Create existing transaction
        create(
          :transaction,
          user: user,
          bank_account: bank_account,
          date: Date.parse("2024-01-15"),
          description: "Test Transaction",
          amount: 100.00,
          source: :manual
        )

        statement_file.update(parsed_json: { "transactions" => [ transaction_data ] })
      end

      it 'detects exact duplicates' do
        result = service.call
        expect(result.success?).to be true
        expect(result.payload.length).to eq(1)
        expect(result.payload.first[:existing_transactions].length).to eq(1)
      end
    end

    context 'when there are similar duplicates' do
      let(:transaction_data) do
        {
          "date" => "2024-01-15",
          "description" => "Test Transaction Walmart",
          "amount" => "100.00",
          "transaction_type" => "income"
        }
      end

      before do
        # Create existing transaction with similar description
        create(
          :transaction,
          user: user,
          bank_account: bank_account,
          date: Date.parse("2024-01-15"),
          description: "Test Transaction at Walmart",
          amount: 100.00,
          source: :manual
        )

        statement_file.update(parsed_json: { "transactions" => [ transaction_data ] })
      end

      it 'detects similar duplicates' do
        result = service.call
        expect(result.success?).to be true
        expect(result.payload.length).to eq(1)
        expect(result.payload.first[:existing_transactions].length).to eq(1)
      end
    end

    context 'when there are no duplicates' do
      let(:transaction_data) do
        {
          "date" => "2024-01-15",
          "description" => "Unique Transaction",
          "amount" => "100.00",
          "transaction_type" => "income"
        }
      end

      before do
        statement_file.update(parsed_json: { "transactions" => [ transaction_data ] })
      end

      it 'returns empty array' do
        result = service.call
        expect(result.success?).to be true
        expect(result.payload).to eq([])
      end
    end
  end

  describe 'concept-based duplicate detection' do
    let(:manual_transaction) do
      create(
        :transaction,
        user: user,
        bank_account: bank_account,
        date: Date.parse("2024-01-15"),
        description: "mueble pecera",
        concept: "mueble pecera",
        amount: -2600.00,
        source: :manual
      )
    end

    before { manual_transaction }

    it 'detects duplicate via concept when raw descriptions are too dissimilar' do
      statement_file.update(
        parsed_json: {
                "transactions" => [
                  {
                    "date" => "2024-01-15",
                    "description" => "SPEI ENVIADO BANORTE 0097161491 072 1803260mueble pecera MBAN Oscar Amaro",
                    "concept" => "SPEI ENVIADO mueble pecera Oscar Amaro",
                    "amount" => "-2600.00",
                    "transaction_type" => "variable_expense"
                  }
                ]
              }
      )

      result = service.call
      expect(result.success?).to be true
      expect(result.payload.length).to eq(1)
      expect(result.payload.first[:existing_transactions]).to include(manual_transaction)
    end

    it 'does not flag as duplicate when concept does not match' do
      statement_file.update(
        parsed_json: {
                "transactions" => [
                  {
                    "date" => "2024-01-15",
                    "description" => "SPEI ENVIADO BANORTE 0097161491 compra completamente diferente",
                    "concept" => "SPEI ENVIADO compra completamente diferente",
                    "amount" => "-2600.00",
                    "transaction_type" => "variable_expense"
                  }
                ]
              }
      )

      result = service.call
      expect(result.success?).to be true
      expect(result.payload).to be_empty
    end
  end
end
