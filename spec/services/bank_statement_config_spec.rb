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

  describe '#get_header_extraction' do
    it 'returns BBVA header extraction patterns' do
      headers = config.get_header_extraction('bbva')
      expect(headers['account_info']).to include('Cuenta:')
      expect(headers['statement_period']).to include('Periodo:')
      expect(headers['balance_info']).to include('Saldo Inicial:')
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

  # New methods for parser selection
  describe '#get_parser_for_bank_account' do
    it 'returns "bbva_savings" for BBVA debit accounts' do
      bbva_bank = Bank.find_by(code: "bbva")
      bbva_account = create(:bank_account, bank: bbva_bank, user: user, account_type: "debit")
      parser_type = config.get_parser_for_bank_account(bbva_account)
      expect(parser_type).to eq('bbva_savings')
    end

    it 'returns "bbva_credit_card" for BBVA credit accounts' do
      bbva_bank = Bank.find_by(code: "bbva")
      bbva_account = create(:bank_account, bank: bbva_bank, user: user, account_type: "credit")
      parser_type = config.get_parser_for_bank_account(bbva_account)
      expect(parser_type).to eq('bbva_credit_card')
    end

    it 'returns "generic" for generic bank accounts' do
      generic_bank = Bank.find_by(code: "generic")
      generic_account = create(:bank_account, bank: generic_bank, user: user)
      parser_type = config.get_parser_for_bank_account(generic_account)
      expect(parser_type).to eq('generic')
    end

    it 'returns "generic" for unsupported bank accounts' do
      unsupported_bank = create(:bank, code: 'unknown', name: 'Unknown', supported: false)
      unsupported_account = create(:bank_account, bank: unsupported_bank, user: user)

      parser_type = config.get_parser_for_bank_account(unsupported_account)
      expect(parser_type).to eq('generic')
    end

    it 'returns "generic" when bank account has no bank' do
      account_without_bank = build(:bank_account, bank: nil, user: user)
      parser_type = config.get_parser_for_bank_account(account_without_bank)
      expect(parser_type).to eq('generic')
    end
  end
end
