require 'rails_helper'

RSpec.describe BankStatementConfig do
  let(:config) { described_class.instance }
  let(:user) { create(:user) }
  let(:bbva_bank) { create(:bank, :bbva) }
  let(:generic_bank) { create(:bank, :generic) }
  let(:bbva_account) { create(:bank_account, bank: bbva_bank, user: user) }
  let(:generic_account) { create(:bank_account, bank: generic_bank, user: user) }

  describe '#bank_config' do
    it 'returns BBVA configuration' do
      bbva_config = config.bank_config('bbva')
      expect(bbva_config).to be_present
      expect(bbva_config['name']).to eq('BBVA Bancomer')
    end

    it 'returns nil for unknown bank' do
      unknown_config = config.bank_config('unknown_bank')
      expect(unknown_config).to be_nil
    end

    it 'normalizes bank names' do
      bbva_config = config.bank_config('BBVA')
      expect(bbva_config).to be_present
      expect(bbva_config['name']).to eq('BBVA Bancomer')
    end
  end

  describe '#get_transaction_patterns' do
    it 'returns BBVA transaction patterns' do
      patterns = config.get_transaction_patterns('bbva')
      # Tests that patterns are returned (specific patterns may vary based on variation selection)
      expect(patterns).to be_an(Array)
      expect(patterns).not_to be_empty
      # Should include some transaction-related patterns
      expect(patterns.any? { |p| p.include?('CARGOS') || p.include?('ABONOS') || p.include?('PAGO') }).to be true
    end

    it 'returns empty array for unknown bank' do
      patterns = config.get_transaction_patterns('unknown_bank')
      expect(patterns).to eq([])
    end
  end

  describe '#get_non_transaction_patterns' do
    it 'returns BBVA non-transaction patterns' do
      patterns = config.get_non_transaction_patterns('bbva')
      # Tests that patterns are returned (specific patterns may vary based on variation selection)
      expect(patterns).to be_an(Array)
      expect(patterns).not_to be_empty
      # Should include some non-transaction patterns
      expect(patterns.any? { |p| p.include?('Estado') || p.include?('PAGINA') }).to be true
    end
  end

  describe '#get_transaction_codes' do
    it 'returns BBVA transaction codes' do
      codes = config.get_transaction_codes('bbva')
      # Tests that codes are returned (specific codes may vary based on variation selection)
      expect(codes).to be_an(Array)
      expect(codes).not_to be_empty
    end
  end

  describe '#get_financial_extraction' do
    it 'returns BBVA financial extraction patterns' do
      financial = config.get_financial_extraction('bbva')
      expect(financial).to be_a(Hash)
      expect(financial['statement_type']).to be_present
    end
  end

  describe '#supported_banks' do
    it 'returns list of supported banks' do
      banks = config.supported_banks
      expect(banks).to include('bbva')
      expect(banks).to include('banamex')
      expect(banks).to include('banorte')
    end
  end

  describe '#bank_display_name' do
    it 'returns BBVA display name' do
      name = config.bank_display_name('bbva')
      expect(name).to eq('BBVA Bancomer')
    end

    it 'returns normalized name for unknown bank' do
      name = config.bank_display_name('unknown_bank')
      expect(name).to eq('unknown_bank')
    end
  end

  describe '#global_patterns' do
    it 'returns global patterns' do
      global = config.global_patterns
      expect(global['date_formats']).to include('DD/MM/YYYY')
      expect(global['amount_formats']).to include('\\d{1,3}(?:,\\d{3})*\\.\\d{2}')
    end
  end

  describe '#get_statement_type' do
    it 'returns statement type for BBVA' do
      statement_type = config.get_statement_type('bbva')
      expect(statement_type).to be_present
      expect(statement_type).to be_a(String)
    end

    it 'returns default statement type for unknown bank' do
      statement_type = config.get_statement_type('unknown')
      expect(statement_type).to eq('savings')
    end
  end
end
