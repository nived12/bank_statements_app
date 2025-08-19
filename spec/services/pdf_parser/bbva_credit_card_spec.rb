# spec/services/pdf_parser/bbva_credit_card_spec.rb
require 'rails_helper'

RSpec.describe PdfParser::BbvaCreditCard do
  let(:parser) { described_class.new }

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

          TOTAL CARGOS: $85,591.03
          TOTAL ABONOS: -$54,538.87
        TEXT
      end

      it 'detects new format and delegates to NewBbvaCreditCard' do
        # Mock the new parser to return a known result
        new_parser = instance_double(PdfParser::NewBbvaCreditCard)
        allow(PdfParser::NewBbvaCreditCard).to receive(:new).and_return(new_parser)
        allow(new_parser).to receive(:parse).and_return({
          'extraction_source' => 'new_bbva_credit_card_parser_deterministic',
          'transactions' => [
            { 'date' => '2025-06-21', 'description' => 'STARBUCKS STORE 05775', 'amount' => '-348.21' }
          ]
        })

        result = parser.parse(text)

        expect(PdfParser::NewBbvaCreditCard).to have_received(:new)
        expect(new_parser).to have_received(:parse).with(text, context: {})
        expect(result['extraction_source']).to eq('new_bbva_credit_card_parser_deterministic')
      end

      it 'detects new format indicators correctly' do
        expect(parser.send(:is_new_format?, text.split("\n"))).to be true
      end
    end

    context 'with legacy BBVA format (pre-July 2024)' do
      let(:text) do
        <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          Movimientos Efectuados
          Tarjeta Titular 1234 5678 9012 3456

          FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
          15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | | | 348.21 |#{' '}
          15/06/25 | 17/06/25 | HEB VALLE ALTO | | | 1,166.00 |#{' '}

          TOTAL IMPORTES
        TEXT
      end

      it 'detects legacy format and delegates to OldBbvaCreditCard' do
        # Mock the old parser to return a known result
        old_parser = instance_double(PdfParser::OldBbvaCreditCard)
        allow(PdfParser::OldBbvaCreditCard).to receive(:new).and_return(old_parser)
        allow(old_parser).to receive(:parse).and_return({
          'extraction_source' => 'old_bbva_credit_card_parser_deterministic',
          'transactions' => [
            { 'date' => '2025-06-15', 'description' => 'STARBUCKS STORE 05775', 'amount' => '-348.21' }
          ]
        })

        result = parser.parse(text)

        expect(PdfParser::OldBbvaCreditCard).to have_received(:new)
        expect(old_parser).to have_received(:parse).with(text, context: {})
        expect(result['extraction_source']).to eq('old_bbva_credit_card_parser_deterministic')
      end

      it 'does not detect new format indicators' do
        expect(parser.send(:is_new_format?, text.split("\n"))).to be false
      end
    end

    context 'with ambiguous format' do
      let(:text) do
        <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          Some generic text that doesn't match either format

          15/06/25 STARBUCKS STORE 05775 348.21
          21-jun-2025 STARBUCKS STORE 05775 +$348.21
        TEXT
      end

      it 'defaults to legacy format when no clear indicators found' do
        # Mock the old parser to return a known result
        old_parser = instance_double(PdfParser::OldBbvaCreditCard)
        allow(PdfParser::OldBbvaCreditCard).to receive(:new).and_return(old_parser)
        allow(old_parser).to receive(:parse).and_return({
          'extraction_source' => 'old_bbva_credit_card_parser_deterministic',
          'transactions' => []
        })

        result = parser.parse(text)

        expect(PdfParser::OldBbvaCreditCard).to have_received(:new)
        expect(result['extraction_source']).to eq('old_bbva_credit_card_parser_deterministic')
      end
    end

    context 'with mixed format indicators' do
      let(:text) do
        <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          Movimientos Efectuados
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)

          15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | | | 348.21 |#{' '}
          21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$348.21
        TEXT
      end

      it 'prioritizes new format when both indicators are present' do
        # Mock the new parser to return a known result
        new_parser = instance_double(PdfParser::NewBbvaCreditCard)
        allow(PdfParser::NewBbvaCreditCard).to receive(:new).and_return(new_parser)
        allow(new_parser).to receive(:parse).and_return({
          'extraction_source' => 'new_bbva_credit_card_parser_deterministic',
          'transactions' => []
        })

        result = parser.parse(text)

        expect(PdfParser::NewBbvaCreditCard).to have_received(:new)
        expect(result['extraction_source']).to eq('new_bbva_credit_card_parser_deterministic')
      end
    end

    context 'with context parameter' do
      let(:text) { 'CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)' }
      let(:context) { { 'user_id' => 123, 'bank_id' => 456 } }

      it 'passes context to the delegated parser' do
        new_parser = instance_double(PdfParser::NewBbvaCreditCard)
        allow(PdfParser::NewBbvaCreditCard).to receive(:new).and_return(new_parser)
        allow(new_parser).to receive(:parse).and_return({ 'transactions' => [] })

        parser.parse(text, context: context)

        expect(new_parser).to have_received(:parse).with(text, context: context)
      end
    end
  end

  describe '#is_new_format?' do
    it 'detects new format indicators correctly' do
      new_format_indicators = [
        'CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)',
        'COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES',
        'RESUMEN DE CARGOS Y ABONOS DEL PERIODO',
        'DISTRIBUCIÓN DE TU ÚLTIMO PAGO'
      ]

      new_format_indicators.each do |indicator|
        lines = [ "Some text", indicator, "More text" ]
        expect(parser.send(:is_new_format?, lines)).to be true
      end
    end

    it 'does not detect new format when indicators are absent' do
      legacy_lines = [
        'Movimientos Efectuados',
        'FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO',
        'TOTAL IMPORTES'
      ]

      expect(parser.send(:is_new_format?, legacy_lines)).to be false
    end

    it 'handles case sensitivity correctly' do
      mixed_case_lines = [
        'cargos, compras y abonos regulares (no a meses)',
        'COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES'
      ]

      expect(parser.send(:is_new_format?, mixed_case_lines)).to be true
    end
  end

  context 'integration with actual parsers' do
    let(:new_format_text) do
      <<~TEXT
        CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)
        21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$348.21
      TEXT
    end

    let(:legacy_format_text) do
      <<~TEXT
        Movimientos Efectuados
        15/06/25 STARBUCKS STORE 05775 IMPORTE CARGOS: 348.21
      TEXT
    end

    it 'successfully parses new format through delegation' do
      result = parser.parse(new_format_text)

      expect(result['extraction_source']).to eq('new_bbva_credit_card_parser_deterministic')
      expect(result['transactions']).to be_an(Array)
      expect(result['transactions'].length).to eq(1)
      expect(result['transactions'].first['amount']).to eq('-348.21')
    end

    it 'successfully parses legacy format through delegation' do
      result = parser.parse(legacy_format_text)

      expect(result['extraction_source']).to eq('old_bbva_credit_card_parser_deterministic')
      expect(result['transactions']).to be_an(Array)
      expect(result['transactions'].length).to eq(1)
      expect(result['transactions'].first['amount']).to eq('-348.21')
    end
  end
end
