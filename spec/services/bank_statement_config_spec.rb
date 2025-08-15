require 'rails_helper'

RSpec.describe BankStatementConfig do
  let(:config) { described_class.instance }

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
      expect(patterns).to include('PAGO DE NOMINA')
      expect(patterns).to include('SPEI ENVIADO')
      expect(patterns).to include('DEPOSITO DE TERCERO')
    end

    it 'returns empty array for unknown bank' do
      patterns = config.get_transaction_patterns('unknown_bank')
      expect(patterns).to eq([])
    end
  end

  describe '#get_non_transaction_patterns' do
    it 'returns BBVA non-transaction patterns' do
      patterns = config.get_non_transaction_patterns('bbva')
      expect(patterns).to include('Estado de Cuenta')
      expect(patterns).to include('PAGINA \\d+ / \\d+')
      expect(patterns).to include('Saldo Promedio')
    end
  end

  describe '#get_transaction_codes' do
    it 'returns BBVA transaction codes' do
      codes = config.get_transaction_codes('bbva')
      expect(codes).to include('R01')
      expect(codes).to include('T16')
      expect(codes).to include('W02')
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
end
