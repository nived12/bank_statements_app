# spec/services/pdf_parser/bbva_credit_card_spec.rb
require 'rails_helper'

RSpec.describe PdfParser::BbvaCreditCard do
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
        mock_result = double(success?: true, payload: {
          'extraction_source' => 'deterministic_parser',
          'transactions' => [
            { 'date' => '2025-06-21', 'description' => 'STARBUCKS STORE 05775', 'amount' => '-348.21' }
          ]
        })
        allow(PdfParser::NewBbvaCreditCard).to receive(:call).and_return(mock_result)

        result = described_class.call(text)

        expect(PdfParser::NewBbvaCreditCard).to have_received(:call).with(text)
        expect(result.success?).to be true
        expect(result.payload['extraction_source']).to eq('deterministic_parser')
      end

      it 'detects new format indicators correctly' do
        parser_instance = described_class.new(text)
        expect(parser_instance.send(:new_format_detected?, text.split("\n"))).to be true
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
          15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | | | 348.21 |#{" "}
          15/06/25 | 17/06/25 | HEB VALLE ALTO | | | 1,166.00 |#{" "}

          TOTAL IMPORTES
        TEXT
      end

      it 'detects legacy format and delegates to OldBbvaCreditCard' do
        # Mock the old parser to return a known result
        mock_result = double(success?: true, payload: {
          'extraction_source' => 'standard_parser',
          'transactions' => [
            { 'date' => '2025-06-15', 'description' => 'STARBUCKS STORE 05775', 'amount' => '-348.21' }
          ]
        })
        allow(PdfParser::OldBbvaCreditCard).to receive(:call).and_return(mock_result)

        result = described_class.call(text)

        expect(PdfParser::OldBbvaCreditCard).to have_received(:call).with(text)
        expect(result.success?).to be true
        expect(result.payload['extraction_source']).to eq('standard_parser')
      end

      it 'does not detect new format indicators' do
        parser_instance = described_class.new(text)
        expect(parser_instance.send(:new_format_detected?, text.split("\n"))).to be false
      end
    end

    context 'with ambiguous format' do
      let(:text) do
        <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          Some generic text that doesn't match either format

          15/06/25 STARBUCKS STORE 05775 348.21
          21-jun-2025 STARBUCKS STORE 05775 348.21
        TEXT
      end

      it 'defaults to legacy format when no clear indicators found' do
        # Mock the old parser to return a known result
        mock_result = double(success?: true, payload: {
          'extraction_source' => 'standard_parser',
          'transactions' => []
        })
        allow(PdfParser::OldBbvaCreditCard).to receive(:call).and_return(mock_result)

        result = described_class.call(text)

        expect(PdfParser::OldBbvaCreditCard).to have_received(:call).with(text)
        expect(result.success?).to be true
        expect(result.payload['extraction_source']).to eq('standard_parser')
      end
    end

    context 'with mixed format indicators' do
      let(:text) do
        <<~TEXT
          BBVA
          Número de cuenta: XXXXXX9496

          Movimientos Efectuados
          CARGOS, COMPRAS Y ABONOS REGULARES (NO A MESES)

          15/06/25 | 17/06/25 | STARBUCKS STORE 05775 | | | 348.21 |#{" "}
          21-jun-2025  23-jun-2025  STARBUCKS STORE 05775     +$348.21
        TEXT
      end

      it 'prioritizes new format when both indicators are present' do
        # Mock the new parser to return a known result
        mock_result = double(success?: true, payload: {
          'extraction_source' => 'deterministic_parser',
          'transactions' => []
        })
        allow(PdfParser::NewBbvaCreditCard).to receive(:call).and_return(mock_result)

        result = described_class.call(text)

        expect(PdfParser::NewBbvaCreditCard).to have_received(:call).with(text)
        expect(result.success?).to be true
        expect(result.payload['extraction_source']).to eq('deterministic_parser')
      end
    end
  end

  describe '#new_format_detected?' do
    it 'detects new format indicators correctly' do
      new_format_indicators = [
        'CARGOS,COMPRAS Y ABONOS REGULARES(NO A MESES)',
        'COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES',
        'DISTRIBUCIÓN DE TU ÚLTIMO PAGO'
      ]

      new_format_indicators.each do |indicator|
        lines = [ "Some text", indicator, "More text" ]
        parser_instance = described_class.new("dummy text")
        expect(parser_instance.send(:new_format_detected?, lines)).to be true
      end
    end

    it 'does not detect new format when indicators are absent' do
      legacy_lines = [
        'Movimientos Efectuados',
        'FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO',
        'TOTAL IMPORTES'
      ]

      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:new_format_detected?, legacy_lines)).to be false
    end

    it 'handles case sensitivity correctly' do
      mixed_case_lines = [
        'cargos, compras y abonos regulares (no a meses)',
        'COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES'
      ]

      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:new_format_detected?, mixed_case_lines)).to be true
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
      result = described_class.call(new_format_text)

      expect(result.success?).to be true
      expect(result.payload['extraction_source']).to eq('deterministic_parser')
      expect(result.payload['transactions']).to be_an(Array)
      expect(result.payload['transactions'].length).to eq(1)
      expect(result.payload['transactions'].first['amount']).to eq('-348.21')
    end

    it 'successfully parses legacy format through delegation' do
      result = described_class.call(legacy_format_text)

      expect(result.success?).to be true
      expect(result.payload['extraction_source']).to eq('standard_parser')
      expect(result.payload['transactions']).to be_an(Array)
      expect(result.payload['transactions'].length).to eq(1)
      expect(result.payload['transactions'].first['amount']).to eq('-348.21')
    end
  end
end
