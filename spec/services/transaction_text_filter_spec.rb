require 'rails_helper'

RSpec.describe TransactionTextFilter do
  let(:bbva_text) do
    <<~TEXT
      Estado de Cuenta BBVA Bancomer
      Cuenta: 0123456789
      Cliente: JUAN PEREZ
      RFC: ABC123456DEF
      Periodo: Mayo 2021
      Saldo Promedio: 316,031.10

      24/MAY W02 DEPOSITO DE TERCERO 3,778.00
      25/MAY R01 PAGO DE NOMINA 15,000.00
      26/MAY T16 SPEI ENVIADO BANSI -71,897.81

      Saldo Final: 250,000.00
    TEXT
  end

  let(:generic_text) do
    <<~TEXT
      Estado de Cuenta
      No. Cuenta: 123456789
      No. Cliente: 987654321

      01/01 PAGO NOMINA 5,000.00
      02/01 TRANSFERENCIA -1,000.00

      Saldo Promedio: 4,000.00
    TEXT
  end

  describe '.filter_for_transactions' do
    context 'with BBVA text' do
      it 'filters out non-transaction content' do
        filtered = described_class.filter_for_transactions(bbva_text, bank_name: 'BBVA')

        expect(filtered).to include('24/MAY W02 DEPOSITO DE TERCERO 3,778.00')
        expect(filtered).to include('25/MAY R01 PAGO DE NOMINA 15,000.00')
        expect(filtered).to include('26/MAY T16 SPEI ENVIADO BANSI -71,897.81')

        expect(filtered).not_to include('Estado de Cuenta BBVA Bancomer')
        expect(filtered).not_to include('Cuenta: 0123456789')
        expect(filtered).not_to include('Saldo Promedio: 316,031.10')
        expect(filtered).not_to include('Saldo Final: 250,000.00')
      end
    end

    context 'with generic text' do
      it 'filters out non-transaction content using generic patterns' do
        filtered = described_class.filter_for_transactions(generic_text, bank_name: 'unknown_bank')

        expect(filtered).to include('01/01 PAGO NOMINA 5,000.00')
        expect(filtered).to include('02/01 TRANSFERENCIA -1,000.00')

        expect(filtered).not_to include('Estado de Cuenta')
        expect(filtered).not_to include('No. Cuenta: 123456789')
        expect(filtered).not_to include('Saldo Promedio: 4,000.00')
      end
    end

    context 'with no bank name' do
      it 'uses generic patterns' do
        filtered = described_class.filter_for_transactions(generic_text)

        expect(filtered).to include('01/01 PAGO NOMINA 5,000.00')
        expect(filtered).to include('02/01 TRANSFERENCIA -1,000.00')
      end
    end
  end

  describe '.extract_headers' do
    context 'with BBVA text' do
      it 'extracts account information' do
        headers = described_class.extract_headers(bbva_text, bank_name: 'BBVA')

        expect(headers['account_info']).to include('0123456789')
        expect(headers['account_info']).to include('JUAN PEREZ')
        expect(headers['account_info']).to include('ABC123456DEF')
        expect(headers['statement_period']).to include('Mayo 2021')
        expect(headers['balance_info']).to include('316,031.10')
      end
    end

    context 'with generic text' do
      it 'returns empty headers for unknown bank' do
        headers = described_class.extract_headers(generic_text, bank_name: 'unknown_bank')
        expect(headers).to eq({})
      end
    end
  end

  describe '.detect_bank_type' do
    it 'detects BBVA variations' do
      expect(described_class.send(:detect_bank_type, 'BBVA')).to eq('bbva')
      expect(described_class.send(:detect_bank_type, 'Bancomer')).to eq('bbva')
      expect(described_class.send(:detect_bank_type, 'bbva')).to eq('bbva')
    end

    it 'detects Banamex' do
      expect(described_class.send(:detect_bank_type, 'Banamex')).to eq('banamex')
      expect(described_class.send(:detect_bank_type, 'banamex')).to eq('banamex')
    end

    it 'detects other banks' do
      expect(described_class.send(:detect_bank_type, 'Banorte')).to eq('banorte')
      expect(described_class.send(:detect_bank_type, 'Santander')).to eq('santander')
      expect(described_class.send(:detect_bank_type, 'HSBC')).to eq('hsbc')
      expect(described_class.send(:detect_bank_type, 'Scotiabank')).to eq('scotiabank')
    end

    it 'returns generic for unknown banks' do
      expect(described_class.send(:detect_bank_type, 'Unknown Bank')).to eq('generic')
      expect(described_class.send(:detect_bank_type, nil)).to eq('generic')
    end
  end

  describe '.is_transaction_continuation?' do
    let(:previous_lines) { [ '24/MAY W02 DEPOSITO DE TERCERO' ] }

    it 'identifies continuation lines for BBVA' do
      continuation_line = 'BANCO AZTECA'
      result = described_class.send(:is_transaction_continuation?, continuation_line, previous_lines, 'bbva')
      expect(result).to be true
    end

    it 'identifies continuation lines for generic banks' do
      continuation_line = 'BANCO AZTECA'
      result = described_class.send(:is_transaction_continuation?, continuation_line, previous_lines, 'generic')
      expect(result).to be true
    end

    it 'does not identify non-continuation lines' do
      non_continuation_line = '25/MAY R01 PAGO DE NOMINA 15,000.00'
      result = described_class.send(:is_transaction_continuation?, non_continuation_line, previous_lines, 'bbva')
      expect(result).to be false
    end
  end
end
