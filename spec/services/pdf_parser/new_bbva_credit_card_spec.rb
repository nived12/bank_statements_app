# spec/services/pdf_parser/new_bbva_credit_card_spec.rb
require 'rails_helper'

RSpec.describe PdfParser::NewBbvaCreditCard do
  describe '#parse' do
    context 'with new BBVA format (July 2024+)' do
      let(:text) do
        <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          RESUMEN DE CARGOS Y ABONOS DEL PERIODO
          Adeudo del periodo anterior: $54,538.87
          Cargos regulares (no a meses): + $48,351.03
          Pagos y abonos: - $54,538.87

          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          Tarjeta titular: XXXXXXXXXXXX9496

          21-jun-2025  23-jun-2025  TST*THE WINDOW - HOLLYWO  +$193.20
          21-jun-2025  23-jun-2025  HOLLYWOOD 21 MARKET       +$500.73
          21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$348.21
          21-jun-2025  23-jun-2025  RAISING CANES 0387        +$409.07
          21-jun-2025  23-jun-2025  ROSS STORES N414          +$2,323.03

          TOTAL CARGOS: $85,591.03
          TOTAL ABONOS: -$54,538.87

          NOTAS ACLARATORIAS
        TEXT
      end

      it 'detects and parses new format correctly' do
        result = described_class.call(text)

        expect(result.success?).to be true
        expect(result.payload).to include(
          'extraction_source' => 'ai_enhanced_parser'
        )
        expect(result.payload['transactions']).to be_an(Array)
        expect(result.payload['transactions'].length).to eq(5)
      end

      it 'correctly inverts signs for expenses and payments' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        # Expenses should be negative (positive in statement, negative in our system)
        expect(transactions.find { |t| t['description'].include?('STARBUCKS') }['amount']).to eq('-348.21')
        expect(transactions.find { |t| t['description'].include?('ROSS STORES') }['amount']).to eq('-2323.03')

        # All expenses should have negative amounts
        transactions.each do |transaction|
          if transaction['transaction_type'] == 'variable_expense'
            expect(transaction['amount'].to_f).to be < 0
            expect(transaction['bank_entry_type']).to eq('debit')
          end
        end
      end

      it 'extracts correct transaction details' do
        result = described_class.call(text)
        transaction = result.payload['transactions'].first

        expect(transaction).to include(
          'date' => '2025-06-21',
          'description' => 'TST*THE WINDOW - HOLLYWO',
          'transaction_type' => 'variable_expense',
          'bank_entry_type' => 'debit',
          'merchant' => 'TST*THE WINDOW - HOLLYWO',
          'category' => 'Sin Categorizar'
        )
        expect(transaction['amount']).to eq('-193.20')
      end

      it 'handles different date formats correctly' do
        text_with_different_dates = <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          01-may-2025  03-may-2025  HOME DEPOT CUMBRE         +$9,480.00
          14-jun-2025  16-jun-2025  PLUS PLAZA CUMBRES        +$4,599.00
          06-jul-2025  07-jul-2025  TICKETMASTER BP           +$32,938.00
        TEXT

        result = described_class.call(text_with_different_dates)
        transactions = result.payload['transactions']

        expect(transactions.find { |t| t['description'].include?('HOME DEPOT') }['date']).to eq('2025-05-01')
        expect(transactions.find { |t| t['description'].include?('PLUS PLAZA') }['date']).to eq('2025-06-14')
        expect(transactions.find { |t| t['description'].include?('TICKETMASTER') }['date']).to eq('2025-07-06')
      end

      it 'extracts balances correctly' do
        result = described_class.call(text)

        expect(result.payload['opening_balance']).to eq(54538.87)
        expect(result.payload['closing_balance']).to be_nil # No closing balance in this sample
      end

      it 'skips deferred charges section to avoid duplicates' do
        text_with_deferred_charges = <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          Tarjeta titular: XXXXXXXXXXXX9496

          21-jun-2025  23-jun-2025  TST*THE WINDOW - HOLLYWO  +$193.20
          21-jun-2025  23-jun-2025  HOLLYWOOD 21 MARKET       +$500.73

          COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES
          Tarjeta titular: XXXXXXXXXXXX9496

          06-jul-2025  TICKETMASTER BP ; Tarjeta Digital ***2064  $32,938.00  $30,193.00  $2,745.00  1 de 12  0.00%

          RESUMEN DE CARGOS Y ABONOS DEL PERIODO
          TOTAL CARGOS: $33,631.93
        TEXT

        result = described_class.call(text_with_deferred_charges)
        transactions = result.payload['transactions']

        # Should only have transactions from the regular section
        expect(transactions.length).to eq(2)

        # Should include regular transactions
        expect(transactions.find { |t| t['description'].include?('TST*THE WINDOW') }).to be_present
        expect(transactions.find { |t| t['description'].include?('HOLLYWOOD 21 MARKET') }).to be_present

        # Should NOT include deferred charges (TICKETMASTER BP)
        expect(transactions.find { |t| t['description'].include?('TICKETMASTER BP') }).to be_nil
      end
    end

    context 'with new amount pattern handling corrupted text' do
      let(:text_with_corrupted_amounts) do
        <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          21-jun-2025          23-jun-2025       TST*THE WINDOW - HOLLYWO                                                 + .20
          21-jun-2025          23-jun-2025       STARBUCKS STORE 12345                                                    + .67
          21-jun-2025          23-jun-2025       HOLLYWOOD 21 MARKET                                                      + .73
        TEXT
      end

      it 'handles corrupted amounts with missing decimal parts' do
        result = described_class.call(text_with_corrupted_amounts)
        transactions = result.payload['transactions']

        expect(transactions.length).to eq(3)
        expect(transactions.find { |t| t['description'].include?('TST*THE WINDOW') }['amount']).to eq('-0.20')
        expect(transactions.find { |t| t['description'].include?('STARBUCKS') }['amount']).to eq('-0.67')
        expect(transactions.find { |t| t['description'].include?('HOLLYWOOD') }['amount']).to eq('-0.73')
      end

      it 'correctly parses amounts with different corruption levels' do
        text_various_corruption = <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          21-jun-2025          23-jun-2025       TEST MERCHANT 1                                                           + .01
          21-jun-2025          23-jun-2025       TEST MERCHANT 2                                                           + 1.00
          21-jun-2025          23-jun-2025       TEST MERCHANT 3                                                           + 123.45
          21-jun-2025          23-jun-2025       TEST MERCHANT 4                                                           + 1,234.56
        TEXT

        result = described_class.call(text_various_corruption)
        transactions = result.payload['transactions']

        expect(transactions.length).to eq(4)
        expect(transactions.find { |t| t['description'].include?('TEST MERCHANT 1') }['amount']).to eq('-0.01')
        expect(transactions.find { |t| t['description'].include?('TEST MERCHANT 2') }['amount']).to eq('-1.00')
        expect(transactions.find { |t| t['description'].include?('TEST MERCHANT 3') }['amount']).to eq('-123.45')
        expect(transactions.find { |t| t['description'].include?('TEST MERCHANT 4') }['amount']).to eq('-1234.56')
      end
    end

    context 'with double-date format handling' do
      let(:text_with_double_dates) do
        <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          21-jun-2025          23-jun-2025       TST*THE WINDOW - HOLLYWO                                                 + $193.20
          22-jun-2025          24-jun-2025       STARBUCKS STORE 05775                                                    + $348.21
          23-jun-2025          25-jun-2025       ROSS STORES N414                                                        + $2,323.03
        TEXT
      end

      it 'uses first date for transaction date when multiple dates present' do
        result = described_class.call(text_with_double_dates)
        transactions = result.payload['transactions']

        expect(transactions.length).to eq(3)
        expect(transactions.find { |t| t['description'].include?('TST*THE WINDOW') }['date']).to eq('2025-06-21')
        expect(transactions.find { |t| t['description'].include?('STARBUCKS') }['date']).to eq('2025-06-22')
        expect(transactions.find { |t| t['description'].include?('ROSS STORES') }['date']).to eq('2025-06-23')
      end

      it 'handles mixed single and double date formats' do
        text_mixed_dates = <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          15-jul-2025  TST*SINGLE DATE MERCHANT                                               + $100.00
          21-jun-2025          23-jun-2025       TST*DOUBLE DATE MERCHANT                                                   + $200.00
          25-jul-2025  ANOTHER SINGLE DATE                                                    + $300.00
        TEXT

        result = described_class.call(text_mixed_dates)
        transactions = result.payload['transactions']

        expect(transactions.length).to eq(3)
        expect(transactions.find { |t| t['description'].include?('SINGLE DATE') }['date']).to eq('2025-07-15')
        expect(transactions.find { |t| t['description'].include?('DOUBLE DATE') }['date']).to eq('2025-06-21')
        expect(transactions.find { |t| t['description'].include?('ANOTHER SINGLE') }['date']).to eq('2025-07-25')
      end
    end

    context 'with real-world BBVA statement format' do
      let(:real_world_text) do
        <<~TEXT
          COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES
          Tarjeta titular: XXXXXXXXXXXX9496
          Fecha de la                     Descripción                        Monto        Saldo        Pago       Núm. de       interés
          operación                                                        original    pendiente    requerido      pago       aplicable
          01-may-2025                HOME DEPOT CUMBRE                      $9,480.00    $7,110.00     $790.00      3 de 12      0.00%
          14-jun-2025               PLUS PLAZA CUMBRES                     $4,599.00    $3,065.00     $767.00       2 de 6      0.00%

          CARGOS,COMPRAS Y ABONOS REGULARES(NO A MESES)
          Tarjeta titular: XXXXXXXXXXXX9496
          Fecha               Fecha
          de la             de cargo                              Descripción del movimiento                                Monto
          operación
          21-jun-2025          23-jun-2025       TST*THE WINDOW - HOLLYWO                                                 + $193.20
          USD $10.07 TIPO DE CAMBIO $19.19
          21-jun-2025          23-jun-2025       STARBUCKS STORE 05775                                                    + $348.21
          USD $18.15 TIPO DE CAMBIO $19.19
          26-jun-2025          26-jun-2025        BMOVIL.PAGO TDC                                                                  - $54,538.87
        TEXT
      end

      it 'parses complex real-world BBVA statement format' do
        result = described_class.call(real_world_text)
        transactions = result.payload['transactions']

        # The parser correctly extracts 3 transactions from the regular section
        # and skips the deferred charges section to avoid duplicates
        expect(transactions.length).to eq(3)

        # Check regular transactions
        window_transaction = transactions.find { |t| t['description'].include?('TST*THE WINDOW') }
        expect(window_transaction['date']).to eq('2025-06-21')
        expect(window_transaction['amount']).to eq('-193.20')
        expect(window_transaction['transaction_type']).to eq('variable_expense')

        starbucks_transaction = transactions.find { |t| t['description'].include?('STARBUCKS') }
        expect(starbucks_transaction['date']).to eq('2025-06-21')
        expect(starbucks_transaction['amount']).to eq('-348.21')
        expect(starbucks_transaction['transaction_type']).to eq('variable_expense')

        # Check payment transaction
        payment_transaction = transactions.find { |t| t['description'].include?('BMOVIL.PAGO') }
        expect(payment_transaction['date']).to eq('2025-06-26')
        expect(payment_transaction['amount']).to eq('54538.87')
        expect(payment_transaction['transaction_type']).to eq('income')
      end

      it 'handles USD conversion lines without affecting transaction parsing' do
        result = described_class.call(real_world_text)
        transactions = result.payload['transactions']

        # USD conversion lines should not create transactions
        usd_lines = transactions.select { |t| t['description'].include?('USD') || t['description'].include?('TIPO DE CAMBIO') }
        expect(usd_lines).to be_empty

        # Regular transactions should still be parsed correctly (3 from regular section, deferred charges skipped)
        expect(transactions.length).to eq(3)
      end
    end

    context 'with deferred charges section' do
      let(:text) do
        <<~TEXT
          COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES
          Tarjeta titular: XXXXXXXXXXXX9496

          01-may-2025          03-may-2025       HOME DEPOT CUMBRE                                                         + $9,480.00
          14-jun-2025          16-jun-2025       PLUS PLAZA CUMBRES                                                        + $4,599.00

          TOTAL CARGOS: $13,079.00
        TEXT
      end

      it 'parses deferred charges correctly' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        # Since this text only contains the deferred charges section (which we skip to avoid duplicates),
        # and no regular transactions section, we should get 0 transactions
        expect(transactions.length).to eq(0)

        # The parser correctly skips the deferred charges section to avoid duplicates
        # as these transactions are already included in the regular section
      end
    end

    context 'with mixed transaction types' do
      let(:text) do
        <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)

          21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$39.00
          21-jun-2025  23-jun-2025  HEB VALLE ALTO             +$1,166.00
          21-jun-2025  23-jun-2025  PAGO TARJETA CREDITO      -$500.00
          21-jun-2025  23-jun-2025  ABONO CUENTA              -$1,000.00
        TEXT
      end

      it 'correctly identifies expenses vs payments' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        # Expenses (positive in statement, negative in our system)
        starbucks = transactions.find { |t| t['description'].include?('STARBUCKS') }
        expect(starbucks['amount']).to eq('-39.00')
        expect(starbucks['transaction_type']).to eq('variable_expense')
        expect(starbucks['bank_entry_type']).to eq('debit')

        # Payments (negative in statement, positive in our system)
        payment = transactions.find { |t| t['description'].include?('PAGO TARJETA') }
        expect(payment['amount']).to eq('500.00')
        expect(payment['transaction_type']).to eq('income')
        expect(payment['bank_entry_type']).to eq('credit')
      end
    end

    context 'with USD conversion information' do
      let(:text) do
        <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)

          21-jun-2025  23-jun-2025  TST*THE WINDOW - HOLLYWO  + .20 USD .07 TIPO DE CAMBIO .19
          21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     + .21 USD .15 TIPO DE CAMBIO .19
        TEXT
      end

      it 'removes USD conversion info from descriptions' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        # The parser now correctly removes USD conversion info
        expect(transactions.first['description']).to eq('TST*THE WINDOW - HOLLYWO')
        expect(transactions.last['description']).to eq('STARBUCKS STORE 05775')
      end
    end

    context 'with card information' do
      let(:text) do
        <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)

          21-jun-2025  23-jun-2025  AMAZON MX MARKETPLACE; Tarjeta Digital ***2064  +$346.00
          21-jun-2025  23-jun-2025  NETFLIX COM CR; Tarjeta Digital ***2064          +$119.00
        TEXT
      end

      it 'removes card information from descriptions' do
        result = described_class.call(text)
        transactions = result.payload['transactions']

        expect(transactions.first['description']).to eq('AMAZON MX MARKETPLACE')
        expect(transactions.last['description']).to eq('NETFLIX COM CR')
      end
    end

    context 'with AI parsing failure' do
      let(:text) do
        <<~TEXT
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
          21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$39.00
        TEXT
      end

      it 'falls back to deterministic parsing when AI fails' do
        # Mock AI parsing to fail
        # Mock the AI parsing to fail
        allow_any_instance_of(described_class).to receive(:parse_with_ai).and_return(nil)

        result = described_class.call(text)

        expect(result.payload['extraction_source']).to eq('ai_enhanced_parser')
        expect(result.payload['transactions'].length).to eq(1)
      end
    end
  end

  describe '#parse_table_line' do
    context 'with single date format' do
      let(:sample_line) do
        "21-jun-2025  TST*THE WINDOW - HOLLYWOOD  +$193.20"
      end

      it 'parses a single transaction line correctly' do
        parser_instance = described_class.new("dummy text")
        result = parser_instance.send(:parse_table_line, sample_line)

        expect(result).to include(
          'date' => '2025-06-21',
          'description' => 'TST*THE WINDOW - HOLLYWOOD',
          'amount' => '-193.20',
          'transaction_type' => 'variable_expense',
          'bank_entry_type' => 'debit'
        )
      end
    end

    context 'with double date format' do
      let(:double_date_line) do
        "21-jun-2025          23-jun-2025       TST*THE WINDOW - HOLLYWOOD                                                 + $193.20"
      end

      it 'parses double date format correctly using first date' do
        parser_instance = described_class.new("dummy text")
        result = parser_instance.send(:parse_table_line, double_date_line)

        expect(result).to include(
          'date' => '2025-06-21',
          'description' => 'TST*THE WINDOW - HOLLYWOOD',
          'amount' => '-193.20',
          'transaction_type' => 'variable_expense',
          'bank_entry_type' => 'debit'
        )
      end
    end

    context 'with corrupted amount format' do
      let(:corrupted_amount_line) do
        "21-jun-2025          23-jun-2025       TST*TEST MERCHANT                                                          + .99"
      end

      it 'parses corrupted amounts correctly' do
        parser_instance = described_class.new("dummy text")
        result = parser_instance.send(:parse_table_line, corrupted_amount_line)

        expect(result).to include(
          'date' => '2025-06-21',
          'description' => 'TST*TEST MERCHANT',
          'amount' => '-0.99',
          'transaction_type' => 'variable_expense',
          'bank_entry_type' => 'debit'
        )
      end
    end

    context 'with payment transaction' do
      let(:payment_line) do
        "26-jun-2025          26-jun-2025        BMOVIL.PAGO TDC                                                                  - $54,538.87"
      end

      it 'parses payment transactions correctly with positive amounts' do
        parser_instance = described_class.new("dummy text")
        result = parser_instance.send(:parse_table_line, payment_line)

        expect(result).to include(
          'date' => '2025-06-26',
          'description' => 'BMOVIL.PAGO TDC',
          'amount' => '54538.87',
          'transaction_type' => 'income',
          'bank_entry_type' => 'credit'
        )
      end
    end
  end

  describe '#extract_description' do
    context 'with double date format' do
      let(:line_with_double_dates) do
        "21-jun-2025          23-jun-2025       TST*THE WINDOW - HOLLYWOOD                                                 + $193.20"
      end

      it 'removes both dates from description' do
        # Create a mock amount_match hash that the method now expects
        amount_match = { amount: '193.20', sign: '+' }

        parser_instance = described_class.new("dummy text")
        description = parser_instance.send(:extract_description, line_with_double_dates, nil, amount_match)

        expect(description).to eq('TST*THE WINDOW - HOLLYWOOD')
        expect(description).not_to include('21-jun-2025')
        expect(description).not_to include('23-jun-2025')
      end
    end

    context 'with corrupted amount' do
      let(:line_with_corrupted_amount) do
        "21-jun-2025          23-jun-2025       TEST MERCHANT                                                               + .99"
      end

      it 'removes corrupted amount from description' do
        # Create a mock amount_match hash that the method now expects
        amount_match = { amount: '0.99', sign: '+' }

        parser_instance = described_class.new("dummy text")
        description = parser_instance.send(:extract_description, line_with_corrupted_amount, nil, amount_match)

        expect(description).to eq('TEST MERCHANT')
        expect(description).not_to include('+ .99')
      end
    end
  end

  describe 'AMOUNT_PATTERN constant' do
    it 'matches various amount formats correctly' do
      pattern = PdfParser::NewBbvaCreditCard::AMOUNT_PATTERN

      # Test corrupted amounts (missing decimal part)
      expect("+ .20".match(pattern)).to be_truthy
      expect("+ .99".match(pattern)).to be_truthy
      expect("+ .01".match(pattern)).to be_truthy

      # Test normal amounts
      expect("+ $1.00".match(pattern)).to be_truthy
      expect("+ $123.45".match(pattern)).to be_truthy
      expect("+ $1,234.56".match(pattern)).to be_truthy

      # Test negative amounts
      expect("- $100.00".match(pattern)).to be_truthy
      expect("- $54,538.87".match(pattern)).to be_truthy

      # Test amounts without dollar signs
      expect("+ 100.00".match(pattern)).to be_truthy
      expect("- 100.00".match(pattern)).to be_truthy
    end

    it 'does not match non-amount patterns' do
      pattern = PdfParser::NewBbvaCreditCard::AMOUNT_PATTERN

      # Should not match descriptions (these don't start with + or -)
      expect("TST*THE WINDOW".match(pattern)).to be_falsy
      expect("STARBUCKS STORE".match(pattern)).to be_falsy

      # Should not match partial amounts
      expect("+ .".match(pattern)).to be_falsy
      expect("+ $".match(pattern)).to be_falsy

      # Should not match amounts without proper decimal format
      expect("+ 100".match(pattern)).to be_falsy
      expect("- 200".match(pattern)).to be_falsy

      # Should not match dates (the pattern now requires decimal part)
      expect("+ 2025".match(pattern)).to be_falsy
      expect("- 2025".match(pattern)).to be_falsy
    end
  end

  describe '#extract_merchant' do
    it 'identifies common merchants correctly' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_merchant, 'STARBUCKS STORE 05775')).to eq('STARBUCKS')
      expect(parser_instance.send(:extract_merchant, 'AMAZON MX MARKETPLACE')).to eq('AMAZON')
      expect(parser_instance.send(:extract_merchant, 'NETFLIX COM CR')).to eq('NETFLIX')
      expect(parser_instance.send(:extract_merchant, 'TESLA AUTOMOBILES MX')).to eq('TESLA')
      expect(parser_instance.send(:extract_merchant, 'HOME DEPOT CUMBRE')).to eq('HOME DEPOT')
      expect(parser_instance.send(:extract_merchant, 'TICKETMASTER BP')).to eq('TICKETMASTER')
    end

    it 'falls back to pattern matching for unknown merchants' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_merchant, 'UNKNOWN STORE NAME')).to eq('UNKNOWN STORE NAME')
    end
  end

  describe '#normalize_date' do
    it 'converts DD-MMM-YYYY to YYYY-MM-DD correctly' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:normalize_date, '21', 'jun', '2025')).to eq('2025-06-21')
      expect(parser_instance.send(:normalize_date, '01', 'may', '2025')).to eq('2025-05-01')
      expect(parser_instance.send(:normalize_date, '31', 'dic', '2024')).to eq('2024-12-31')
    end

    it 'handles different month abbreviations' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:normalize_date, '15', 'ene', '2025')).to eq('2025-01-15')
      expect(parser_instance.send(:normalize_date, '20', 'feb', '2025')).to eq('2025-02-20')
      expect(parser_instance.send(:normalize_date, '10', 'mar', '2025')).to eq('2025-03-10')
    end

    it 'returns nil for invalid month' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:normalize_date, '15', 'invalid', '2025')).to be_nil
    end
  end

  describe '#extract_balance_from_lines' do
    it 'extracts opening balance from "Adeudo del periodo anterior"' do
      lines = [ 'Adeudo del periodo anterior: $54,538.87' ]
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_balance_from_lines, lines, 'opening')).to eq(54538.87)
    end

    it 'extracts closing balance from "Saldo deudor total"' do
      lines = [ 'Saldo deudor total: $93,021.03' ]
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_balance_from_lines, lines, 'closing')).to eq(93021.03)
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
        { 'date' => '2025-06-21', 'description' => 'STARBUCKS', 'amount' => '-39.00' },
        { 'date' => '2025-06-21', 'description' => 'STARBUCKS', 'amount' => '-39.00' },
        { 'date' => '2025-06-21', 'description' => 'HEB', 'amount' => '-1166.00' }
      ]

      parser_instance = described_class.new("dummy text")
      result = parser_instance.send(:deduplicate_transactions, transactions)
      expect(result.length).to eq(2)
      expect(result.map { |t| t['description'] }).to match_array([ 'STARBUCKS', 'HEB' ])
    end
  end
end
