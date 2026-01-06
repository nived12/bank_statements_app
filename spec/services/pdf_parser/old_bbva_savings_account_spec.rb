require 'rails_helper'

RSpec.describe PdfParser::OldBbvaSavingsAccount do
  let(:parser) { described_class.new("dummy text") }

  describe '.call' do
    let(:sample_text) do
      <<~TEXT
        BBVA MEXICO INSTITUCION DE BANCA MULTIPLE, S.A., GRUPO FINANCIERO BBVA MEXICO
        Estado de Cuenta de Ahorro

        Periodo DEL 01/07/2025 AL 31/07/2025
        Fecha de Corte 31/07/2025
        No. de Cuenta 1234567890

        Información Financiera
        Saldo Anterior: 1,000.00
        Saldo Final: 2,500.00
        Depósitos / Abonos: 3,000.00
        Retiros / Cargos: 1,500.00
        Intereses a Favor: 0.00
        Saldo Promedio: 1,750.00
        Días del Periodo: 31

        Detalle de Movimientos Realizados
        FECHA SALDO OPER LIQ DESCRIPCIÓN REFERENCIA CARGOS ABONOS OPERACIÓN LIQUIDACIÓN
        03/JUL 03/JUL PAGO DE NOMINA EMPRESA EJEMPLO S.A. DE C.V. NOM001 0.00 2,000.00 2,000.00 2,000.00
        05/JUL 05/JUL RETIRO EN CAJERO AUTOMATICO RET001 500.00 0.00 1,500.00 1,500.00
        10/JUL 10/JUL SPEI RECIBIDO HSBC SPEI001 0.00 1,000.00 2,500.00 2,500.00
        15/JUL 15/JUL PAGO DE SERVICIOS SERV001 300.00 0.00 2,200.00 2,200.00
      TEXT
    end

    context 'with valid text' do
      it 'returns a success response' do
        result = described_class.call(sample_text)
        expect(result.success?).to be true
      end

      it 'extracts transactions correctly' do
        result = described_class.call(sample_text)
        transactions = result.payload['transactions']

        expect(transactions).to be_an(Array)
        expect(transactions.length).to eq(4)

        # Check first transaction (PAGO DE NOMINA - should be income)
        first_transaction = transactions[0]
        expect(first_transaction['date']).to eq('2025-07-03')
        expect(first_transaction['description']).to include('PAGO DE NOMINA')
        expect(first_transaction['amount']).to eq("2000.0")
        expect(first_transaction['transaction_type']).to eq('income')
        expect(first_transaction['reference']).to eq('NOM001')
      end

      it 'classifies deposits as income' do
        result = described_class.call(sample_text)
        transactions = result.payload['transactions']

        # PAGO DE NOMINA should be income
        nomina_transaction = transactions.find { |t| t['description'].include?('PAGO DE NOMINA') }
        expect(nomina_transaction['transaction_type']).to eq('income')
        expect(nomina_transaction['amount']).to eq("2000.0")

        # SPEI RECIBIDO should be income
        spei_transaction = transactions.find { |t| t['description'].include?('SPEI RECIBIDO') }
        expect(spei_transaction['transaction_type']).to eq('income')
        expect(spei_transaction['amount']).to eq("1000.0")
      end

      it 'classifies withdrawals as expenses' do
        result = described_class.call(sample_text)
        transactions = result.payload['transactions']

        # RETIRO should be expense
        retiro_transaction = transactions.find { |t| t['description'].include?('RETIRO') }
        expect(retiro_transaction['transaction_type']).to eq('variable_expense')
        expect(retiro_transaction['amount']).to eq("-500.0")

        # PAGO DE SERVICIOS should be expense
        servicios_transaction = transactions.find { |t| t['description'].include?('PAGO DE SERVICIOS') }
        expect(servicios_transaction['transaction_type']).to eq('variable_expense')
        expect(servicios_transaction['amount']).to eq("-300.0")
      end

      it 'extracts financial summaries correctly' do
        result = described_class.call(sample_text)
        summaries = result.payload['financial_summaries']

        expect(summaries).to be_an(Array)
        expect(summaries.length).to eq(1)

        summary = summaries.first
        expect(summary['statement_type']).to eq('savings')
        expect(summary['bank_name']).to eq('BBVA')
        expect(summary['opening_balance']).to eq(BigDecimal('1000.00'))
        expect(summary['closing_balance']).to eq(BigDecimal('2500.00'))
        expect(summary['total_deposits']).to eq(BigDecimal('3000.00'))
        expect(summary['total_withdrawals']).to eq(BigDecimal('1500.00'))
        expect(summary['interest_earned']).to eq(BigDecimal('0.00'))
        expect(summary['average_balance']).to eq(BigDecimal('1750.00'))
        expect(summary['period_days']).to eq(31)
      end

      it 'includes extraction source' do
        result = described_class.call(sample_text)
        expect(result.payload['extraction_source']).to eq('bbva_savings_parser')
      end
    end

    context 'with empty or invalid text' do
      it 'handles empty text gracefully' do
        result = described_class.call("")
        expect(result.success?).to be true
        expect(result.payload['transactions']).to eq([])
        expect(result.payload['financial_summaries']).to be_an(Array)
        expect(result.payload['financial_summaries'].length).to eq(1)
      end

      it 'handles text without transactions' do
        text_without_transactions = "BBVA MEXICO\nEstado de Cuenta\nInformación Financiera\nSaldo Anterior: 1000.00"
        result = described_class.call(text_without_transactions)
        expect(result.success?).to be true
        expect(result.payload['transactions']).to eq([])
        expect(result.payload['financial_summaries']).to be_an(Array)
      end
    end
  end

  describe 'concern integration' do
    it 'includes all required concerns' do
      expect(described_class.ancestors).to include(
        PdfParser::Concerns::CommonParsingPatterns,
        PdfParser::Concerns::TextProcessing,
        PdfParser::Concerns::DateParsing,
        PdfParser::Concerns::FinancialSummaryExtraction,
        PdfParser::Concerns::TransactionClassification,
        PdfParser::Concerns::TransactionParsing
      )
    end

    it 'uses shared concern methods' do
      parser_instance = described_class.new("dummy text")

      # Test that shared methods are available (using send for private methods)
      expect(parser_instance.send(:clean_ocr_text, "test")).to be_a(String)
      expect(parser_instance.send(:clean_description, "test")).to be_a(String)
      expect(parser_instance.send(:parse_spanish_date, "03/JUL")).to be_a(String)
      expect(parser_instance.send(:create_base_transaction)).to be_a(Hash)
      expect(parser_instance.send(:classify_transaction, {}, 100)).to be_a(Hash)
      expect(parser_instance.send(:is_deposit?, "ABONO")).to be_a(TrueClass)
      expect(parser_instance.send(:is_withdrawal?, "RETIRO")).to be_a(TrueClass)
    end
  end

  describe 'BBVA-specific behavior' do
    it 'overrides is_bank_statement_header? for BBVA patterns' do
      parser_instance = described_class.new("dummy text")
      expect(
        parser_instance.send(
          :is_bank_statement_header?,
          "FECHA SALDO OPER LIQ DESCRIPCIÓN REFERENCIA CARGOS ABONOS OPERACIÓN LIQUIDACIÓN"
        )
      ).to be true
      expect(parser_instance.send(:is_bank_statement_header?, "BBVA MEXICO INSTITUCION DE BANCA MULTIPLE")).to be true
      expect(parser_instance.send(:is_bank_statement_header?, "PAGO DE NOMINA")).to be false
    end

    it 'overrides is_section_break? for BBVA patterns' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:is_section_break?, "ESTADO DE CUENTA")).to be true
      expect(parser_instance.send(:is_section_break?, "BBVA MEXICO INSTITUCION DE BANCA MULTIPLE")).to be true
      expect(parser_instance.send(:is_section_break?, "PAGO DE NOMINA")).to be false
    end

    it 'overrides clean_description for BBVA-specific cleaning' do
      parser_instance = described_class.new("dummy text")
      text = "PAGO DE NOMINA No.deCuenta 1234567890 No.deCliente 987654321 FECHA SALDO OPER LIQ DESCRIPCIÓN REFERENCIA CARGOS ABONOS OPERACIÓN LIQUIDACIÓN"
      result = parser_instance.send(:clean_description, text)
      expect(result).not_to include("No.deCuenta")
      expect(result).not_to include("FECHA SALDO OPER LIQ")
    end

    it 'extracts year from statement period' do
      parser_instance = described_class.new("Periodo DEL 01/07/2025 AL 31/07/2025")
      year = parser_instance.send(:extract_year_from_statement_period)
      expect(year).to eq("2025")
    end
  end
end
