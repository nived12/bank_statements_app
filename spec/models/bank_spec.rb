# spec/models/bank_spec.rb
require 'rails_helper'

RSpec.describe Bank, type: :model do
  describe 'enums' do
    it 'defines supported_type enum correctly' do
      expect(Bank.supported_types).to eq(
        {
                'debit' => 1,
                'credit' => 2,
                'both' => 3
              }
      )
    end
  end

  describe 'scopes' do
    let!(:supported_bank) { create(:bank, supported_type: 'both') }
    let!(:unsupported_bank) { create(:bank, supported_type: nil) }
    let!(:inactive_bank) { create(:bank, supported_type: 'debit', active: false) }

    describe '.supported' do
      it 'returns only banks with supported_type present' do
        expect(Bank.supported).to include(supported_bank)
        expect(Bank.supported).not_to include(unsupported_bank)
      end
    end

    describe '.active' do
      it 'returns only active banks' do
        expect(Bank.active).to include(supported_bank)
        expect(Bank.active).not_to include(inactive_bank)
      end
    end

    describe '.supported_banks' do
      it 'returns supported and active banks' do
        expect(Bank.supported_banks).to include(supported_bank)
        expect(Bank.supported_banks).not_to include(unsupported_bank)
        expect(Bank.supported_banks).not_to include(inactive_bank)
      end
    end
  end

  describe '#supports_account_type?' do
    let(:bank) { create(:bank, supported_type: 'both') }

    context 'when bank supports both types' do
      it 'returns true for debit accounts' do
        expect(bank.supports_account_type?('debit')).to be true
        expect(bank.supports_account_type?('savings')).to be true
        expect(bank.supports_account_type?('checking')).to be true
      end

      it 'returns true for credit accounts' do
        expect(bank.supports_account_type?('credit')).to be true
      end
    end

    context 'when bank supports only debit accounts' do
      let(:bank) { create(:bank, supported_type: 'debit') }

      it 'returns true for debit accounts' do
        expect(bank.supports_account_type?('debit')).to be true
        expect(bank.supports_account_type?('savings')).to be true
      end

      it 'returns false for credit accounts' do
        expect(bank.supports_account_type?('credit')).to be false
      end
    end

    context 'when bank supports only credit accounts' do
      let(:bank) { create(:bank, supported_type: 'credit') }

      it 'returns true for credit accounts' do
        expect(bank.supports_account_type?('credit')).to be true
      end

      it 'returns false for debit accounts' do
        expect(bank.supports_account_type?('debit')).to be false
        expect(bank.supports_account_type?('savings')).to be false
      end
    end

    context 'when bank is unsupported' do
      let(:bank) { create(:bank, supported_type: nil) }

      it 'returns false for all account types' do
        expect(bank.supports_account_type?('debit')).to be false
        expect(bank.supports_account_type?('credit')).to be false
        expect(bank.supports_account_type?('savings')).to be false
      end
    end
  end

  describe '#supported_for_parsing?' do
    let(:bank) { create(:bank, supported_type: 'both', active: true) }

    it 'returns true when supported_type is present and active' do
      expect(bank.supported_for_parsing?).to be true
    end

    it 'returns false when supported_type is nil' do
      bank.update!(supported_type: nil)
      expect(bank.supported_for_parsing?).to be false
    end

    it 'returns false when inactive' do
      bank.update!(active: false)
      expect(bank.supported_for_parsing?).to be false
    end
  end
end
