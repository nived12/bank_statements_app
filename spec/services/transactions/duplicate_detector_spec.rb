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
        create(:transaction,
               user: user,
               bank_account: bank_account,
               date: Date.parse("2024-01-15"),
               description: "Test Transaction",
               amount: 100.00,
               source: :manual)

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
        create(:transaction,
               user: user,
               bank_account: bank_account,
               date: Date.parse("2024-01-15"),
               description: "Test Transaction at Walmart",
               amount: 100.00,
               source: :manual)

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

  describe '#calculate_similarity' do
    it 'returns 1.0 for identical descriptions' do
      similarity = service.send(:calculate_similarity, "Test Transaction", "Test Transaction")
      expect(similarity).to eq(1.0)
    end

    it 'returns 0.0 for completely different descriptions' do
      similarity = service.send(:calculate_similarity, "Test Transaction", "Completely Different")
      expect(similarity).to eq(0.0)
    end

    it 'returns similarity score for partially similar descriptions' do
      similarity = service.send(:calculate_similarity, "Test Transaction Walmart", "Test Transaction at Walmart")
      expect(similarity).to be > 0.5
    end

    it 'returns 0.0 for blank descriptions' do
      similarity = service.send(:calculate_similarity, "", "Test Transaction")
      expect(similarity).to eq(0.0)
    end
  end

  describe '#normalize_description' do
    it 'converts to lowercase' do
      normalized = service.send(:normalize_description, "TEST TRANSACTION")
      expect(normalized).to eq("test transaction")
    end

    it 'removes punctuation' do
      normalized = service.send(:normalize_description, "Test, Transaction!")
      expect(normalized).to eq("test transaction")
    end

    it 'normalizes whitespace' do
      normalized = service.send(:normalize_description, "Test   Transaction")
      expect(normalized).to eq("test transaction")
    end
  end
end
