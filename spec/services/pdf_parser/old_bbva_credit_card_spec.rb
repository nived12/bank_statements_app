# spec/services/pdf_parser/old_bbva_credit_card_spec.rb
require 'rails_helper'

RSpec.describe PdfParser::OldBbvaCreditCard do
  describe '#parse' do
    context 'with legacy BBVA format (pre-July 2024)' do
      let(:text) do
        <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          Movimientos Efectuados
          Tarjeta Titular 1234 5678 9012 3456

          FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
          15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | ABC123456789 | 123456789 | 348.21 |#{" "}
          15/06/25 | 17/06/25 | HEB VALLE ALTO | DEF987654321 | 987654321 | 1,166.00 |#{" "}
          15/06/25 | 17/06/25 | PAGO TARJETA CREDITO | | | | 500.00

          TOTAL IMPORTES
        TEXT
      end

      it 'detects and parses legacy format correctly' do
        result = described_class.call(text)

        expect(result.success?).to be true
        expect(result.payload).to include(
          'extraction_source' => 'standard_parser'
        )
        expect(result.payload['transactions']).to be_an(Array)
        expect(result.payload['transactions'].length).to eq(3)
      end

      it 'correctly handles pipe-separated format' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        # Expenses should be negative
        starbucks = transactions.find { |t| t['description'].include?('STARBUCKS') }
        expect(starbucks['amount']).to eq('-348.21')
        expect(starbucks['transaction_type']).to eq('variable_expense')

        # Payments should be positive
        payment = transactions.find { |t| t['description'].include?('PAGO TARJETA') }
        expect(payment['amount']).to eq('500.00')
        expect(payment['transaction_type']).to eq('income')
      end

      it 'extracts correct transaction details' do
        result = described_class.call(text)
        transaction = result.payload['transactions'].first

        expect(transaction).to include(
          'date' => '2025-06-15',
          'description' => 'STARBUCKS STORE 05775',
          'transaction_type' => 'variable_expense',
          'merchant' => 'STARBUCKS',
          'category' => 'Sin Categorizar',
          'rfc' => 'ABC123456789',
          'reference' => '123456789'
        )
        expect(transaction['amount']).to eq('-348.21')
      end

      it 'handles different date formats correctly' do
        text_with_different_dates = <<~TEXT
          Movimientos Efectuados
          FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
          01/05/25 | 03/05/25 | HOME DEPOT CUMBRE | | | 9,480.00 |#{" "}
          14/06/25 | 16/06/25 | PLUS PLAZA CUMBRES | | | 4,599.00 |#{" "}
          06/07/25 | 07/07/25 | TICKETMASTER BP | | | 32,938.00 |#{" "}
        TEXT

        result = described_class.call(text_with_different_dates)
        transactions = result.payload['transactions']

        expect(transactions.find { |t| t['description'].include?('HOME DEPOT') }['date']).to eq('2025-05-01')
        expect(transactions.find { |t| t['description'].include?('PLUS PLAZA') }['date']).to eq('2025-06-14')
        expect(transactions.find { |t| t['description'].include?('TICKETMASTER') }['date']).to eq('2025-07-06')
      end
    end

    context 'with multiple card sections' do
      let(:text) do
        <<~TEXT
          Movimientos Efectuados
          Tarjeta Titular 1234 5678 9012 3456

          FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
          15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | | | 348.21 |#{" "}

          Tarjeta Titular 9876 5432 1098 7654

          FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
          15/06/25 | 17/06/25 | AMAZON MX MARKETPLACE | | | 346.00 |#{" "}

          Resumen Informativo
        TEXT
      end

      it 'merges sections from the same card correctly' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        expect(transactions.length).to eq(2)
        expect(transactions.map { |t| t['description'] }).to match_array(
          [
                    'STARBUCKS STORE 05775',
                    'AMAZON MX MARKETPLACE'
                  ]
        )
      end
    end

    context 'with free-form transactions' do
      let(:text) do
        <<~TEXT
          Movimientos Efectuados

          15/06/25 STARBUCKS STORE 05775 IMPORTE CARGOS: 348.21
          15/06/25 HEB VALLE ALTO IMPORTE CARGOS: 1,166.00
          15/06/25 PAGO TARJETA CREDITO IMPORTE ABONOS: 500.00
        TEXT
      end

      it 'parses free-form transactions correctly' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        expect(transactions.length).to eq(3)

        # Expenses
        starbucks = transactions.find { |t| t['description'].include?('STARBUCKS') }
        expect(starbucks['amount']).to eq('-348.21')
        expect(starbucks['transaction_type']).to eq('variable_expense')

        # Payments
        payment = transactions.find { |t| t['description'].include?('PAGO TARJETA') }
        expect(payment['amount']).to eq('500.00')
        expect(payment['transaction_type']).to eq('income')
      end
    end

    context 'with individual transaction lines' do
      let(:text) do
        <<~TEXT
          Some header text

          15/06/25 STARBUCKS STORE 05775 348.21
          15/06/25 HEB VALLE ALTO 1,166.00
          15/06/25 PAGO TARJETA CREDITO 500.00

          Some footer text
        TEXT
      end

      it 'parses individual transaction lines when no sections found' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        expect(transactions.length).to eq(3)
        expect(transactions.first['date']).to eq('2025-06-15')
        expect(transactions.first['description']).to eq('STARBUCKS STORE 05775')
      end
    end

    context 'with specific transaction types' do
      let(:text) do
        <<~TEXT
          Movimientos Efectuados

          15/06/25 SIX PREMIER IMPORTE CARGOS: 1,500.00
          15/06/25 NETFLIX COM CR IMPORTE CARGOS: 119.00
          15/06/25 AMAZON MX MARKETPLACE IMPORTE CARGOS: 346.00
          15/06/25 GOOGLE PLAY IMPORTE CARGOS: 99.00
          15/06/25 PLAYTOMIC IMPORTE CARGOS: 250.00
          15/06/25 MELIMAS IMPORTE CARGOS: 800.00
          15/06/25 BESTBUY COM IMPORTE CARGOS: 2,500.00
          15/06/25 VIVA AEROBUS IMPORTE CARGOS: 1,200.00
          15/06/25 SRIA FINANZAS IMPORTE CARGOS: 3,000.00
          15/06/25 CONEKTA IMPORTE CARGOS: 150.00
          15/06/25 PARCO IMPORTE CARGOS: 450.00
        TEXT
      end

      it 'identifies specific merchants correctly' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        expect(transactions.find { |t| t['description'].include?('SIX PREMIER') }['merchant']).to eq('SIX PREMIER')
        expect(transactions.find { |t| t['description'].include?('NETFLIX') }['merchant']).to eq('NETFLIX')
        expect(transactions.find { |t| t['description'].include?('AMAZON') }['merchant']).to eq('AMAZON')
        expect(transactions.find { |t| t['description'].include?('GOOGLE') }['merchant']).to eq('GOOGLE')
        expect(transactions.find { |t| t['description'].include?('PLAYTOMIC') }['merchant']).to eq('PLAYTOMIC')
        expect(transactions.find { |t| t['description'].include?('MELIMAS') }['merchant']).to eq('MELIMAS')
        expect(transactions.find { |t| t['description'].include?('BESTBUY') }['merchant']).to eq('BESTBUY')
        expect(transactions.find { |t| t['description'].include?('VIVA AEROBUS') }['merchant']).to eq('VIVA AEROBUS')
        expect(transactions.find { |t| t['description'].include?('SRIA FINANZAS') }['merchant']).to eq('SRIA FINANZAS')
        expect(transactions.find { |t| t['description'].include?('CONEKTA') }['merchant']).to eq('CONEKTA')
        expect(transactions.find { |t| t['description'].include?('PARCO') }['merchant']).to eq('PARCO')
      end
    end

    context 'with AI parsing failure' do
      let(:text) do
        <<~TEXT
          Movimientos Efectuados
          15/06/25 STARBUCKS STORE 05775 348.21
        TEXT
      end
    end
  end

  describe '#extract_merchant' do
    it 'identifies common merchants correctly' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_merchant, 'SIX PREMIER STORE')).to eq('SIX PREMIER')
      expect(parser_instance.send(:extract_merchant, 'NETFLIX COM CR')).to eq('NETFLIX')
      expect(parser_instance.send(:extract_merchant, 'AMAZON MX MARKETPLACE')).to eq('AMAZON')
      expect(parser_instance.send(:extract_merchant, 'GOOGLE PLAY')).to eq('GOOGLE')
      expect(parser_instance.send(:extract_merchant, 'PLAYTOMIC CLUB')).to eq('PLAYTOMIC')
      expect(parser_instance.send(:extract_merchant, 'MELIMAS STORE')).to eq('MELIMAS')
      expect(parser_instance.send(:extract_merchant, 'BESTBUY COM')).to eq('BESTBUY')
      expect(parser_instance.send(:extract_merchant, 'VIVA AEROBUS')).to eq('VIVA AEROBUS')
      expect(parser_instance.send(:extract_merchant, 'SRIA FINANZAS')).to eq('SRIA FINANZAS')
      expect(parser_instance.send(:extract_merchant, 'CONEKTA PAYMENT')).to eq('CONEKTA')
      expect(parser_instance.send(:extract_merchant, 'PARCO STORE')).to eq('PARCO')
    end

    it 'falls back to pattern matching for unknown merchants' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_merchant, 'UNKNOWN STORE NAME')).to eq('UNKNOWN STORE NAME')
    end
  end

  describe '#normalize_date' do
    it 'converts DD/MM/YY to YYYY-MM-DD correctly' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:normalize_date, '15', '06', '25')).to eq('2025-06-15')
      expect(parser_instance.send(:normalize_date, '01', '05', '25')).to eq('2025-05-01')
      expect(parser_instance.send(:normalize_date, '31', '12', '24')).to eq('2024-12-31')
    end

    it 'handles 4-digit years' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:normalize_date, '15', '06', '2025')).to eq('2025-06-15')
      expect(parser_instance.send(:normalize_date, '01', '05', '2025')).to eq('2025-05-01')
    end

    it 'handles 2-digit years correctly (YY < 50 becomes 20YY)' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:normalize_date, '15', '06', '25')).to eq('2025-06-15')
      expect(parser_instance.send(:normalize_date, '15', '06', '49')).to eq('2049-06-15')
      expect(parser_instance.send(:normalize_date, '15', '06', '50')).to eq('1950-06-15')
      expect(parser_instance.send(:normalize_date, '15', '06', '99')).to eq('1999-06-15')
    end
  end

  describe '#extract_balance_from_lines' do
    it 'extracts balance from "Saldo Nuevo"' do
      lines = [ 'Saldo Nuevo: $54,538.87' ]
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_balance_from_lines, lines, 'opening')).to eq(54538.87)
      expect(parser_instance.send(:extract_balance_from_lines, lines, 'closing')).to eq(54538.87)
    end

    it 'returns nil when balance not found' do
      lines = [ 'Some other text' ]
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_balance_from_lines, lines, 'opening')).to be_nil
    end
  end

  describe '#deduplicate_transactions' do
    it 'removes duplicate transactions based on date, description, and amount' do
      transactions = [
        { 'date' => '2025-06-15', 'description' => 'STARBUCKS', 'amount' => '-348.21', 'raw_text' => 'IMPORTE CARGOS' },
        { 'date' => '2025-06-15', 'description' => 'STARBUCKS', 'amount' => '-348.21', 'raw_text' => 'Other text' },
        { 'date' => '2025-06-15', 'description' => 'HEB', 'amount' => '-1166.00', 'raw_text' => 'IMPORTE CARGOS' }
      ]

      parser_instance = described_class.new("dummy text")
      result = parser_instance.send(:deduplicate_transactions, transactions)
      expect(result.length).to eq(2)

      # Should prefer the one with IMPORTE CARGOS in raw_text
      starbucks = result.find { |t| t['description'] == 'STARBUCKS' }
      expect(starbucks['raw_text']).to eq('IMPORTE CARGOS')
    end
  end

  describe '#determine_type_from_context' do
    it 'identifies payments correctly' do
      line = 'PAGO TARJETA CREDITO 500.00'
      amount = 500.0
      parser_instance = described_class.new("dummy text")
      type = parser_instance.send(:determine_type_from_context, line, amount)
      expect(type).to eq('income')
    end

    it 'identifies fees correctly' do
      line = 'COMISION ANUALIDAD 1,151.00'
      amount = 1151.0
      parser_instance = described_class.new("dummy text")
      type = parser_instance.send(:determine_type_from_context, line, amount)
      expect(type).to eq('variable_expense')
    end

    it 'identifies specific merchants as expenses' do
      line = 'SIX PREMIER STORE 1,500.00'
      amount = 1500.0
      parser_instance = described_class.new("dummy text")
      type = parser_instance.send(:determine_type_from_context, line, amount)
      expect(type).to eq('variable_expense')
    end

    it 'defaults to expense for negative amounts' do
      line = 'Some transaction -500.00'
      amount = -500.0
      parser_instance = described_class.new("dummy text")
      type = parser_instance.send(:determine_type_from_context, line, amount)
      expect(type).to eq('variable_expense')
    end

    it 'defaults to income for positive amounts' do
      line = 'Some transaction 500.00'
      amount = 500.0
      parser_instance = described_class.new("dummy text")
      type = parser_instance.send(:determine_type_from_context, line, amount)
      expect(type).to eq('income')
    end
  end
end
