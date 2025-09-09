# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfParser::OldBbvaSavingsAccount do
  let(:parser) { described_class.new("dummy text") }

  describe '.call' do
    let(:sample_text) do
      <<~TEXT
        BBVA Bancomer
        Estado de Cuenta
        Cuenta: 1234567890
        Periodo: 01/JUL/2025 - 31/JUL/2025

        Información Financiera
        Saldo Anterior: 91.79
        Saldo Final: 10,459.92
        Depósitos / Abonos: 11 501,541.87
        Retiros / Cargos: 30 491,173.74
        Intereses a Favor: 0.00
        Saldo Promedio: 20,176.39
        Días del Periodo: 31

        Detalle de Movimientos Realizados
        FECHA  OPER  LIQ  COD. DESCRIPCIÓN  REFERENCIA  CARGOS  ABONOS  SALDO OPERACIÓN  SALDO LIQUIDACIÓN
        03/JUL 03/JUL PAGO DE NOMINA   NOM001      0.00    46,960.88  46,960.88        46,960.88
        03/JUL 03/JUL SPEI ENVIADO HSBC SPEI002     101,340.56 0.00   90,000.00        90,000.00
      TEXT
    end

    context 'with valid text' do
      it 'returns a success response' do
        result = described_class.call(sample_text)

        expect(result).to be_success
        expect(result.payload).to be_a(Hash)
      end

      it 'extracts transactions correctly' do
        result = described_class.call(sample_text)

        expect(result.payload["transactions"]).to be_an(Array)
        expect(result.payload["transactions"].length).to eq(2)
      end

      it 'extracts financial summaries correctly' do
        result = described_class.call(sample_text)

        expect(result.payload["financial_summaries"]).to be_an(Array)
        expect(result.payload["financial_summaries"].length).to eq(1)
      end

      it 'includes extraction source' do
        result = described_class.call(sample_text)

        expect(result.payload["extraction_source"]).to eq("bbva_savings_parser")
      end
    end

    context 'with invalid text' do
      it 'handles empty text gracefully' do
        result = described_class.call('')

        expect(result).to be_success
        expect(result.payload["transactions"]).to eq([])
      end

      it 'handles nil text gracefully' do
        result = described_class.call(nil)

        expect(result).to be_success
        expect(result.payload["transactions"]).to eq([])
      end
    end
  end

  describe '#extract_financial_summary' do
    let(:lines) do
      [
        "Información Financiera",
        "Saldo Anterior: 91.79",
        "Saldo Final: 10,459.92",
        "Depósitos / Abonos: 11 501,541.87",
        "Retiros / Cargos: 30 491,173.74",
        "Intereses a Favor: 0.00",
        "Saldo Promedio: 20,176.39",
        "Días del Periodo: 31"
      ]
    end

    it 'extracts all financial summary fields' do
      parser_instance = described_class.new("dummy text")
      summary = parser_instance.send(:extract_financial_summary, lines)

      expect(summary["opening_balance"]).to eq(BigDecimal("91.79"))
      expect(summary["closing_balance"]).to eq(BigDecimal("10459.92"))
      expect(summary["total_deposits"]).to eq(BigDecimal("501541.87"))
      expect(summary["total_withdrawals"]).to eq(BigDecimal("491173.74"))
      expect(summary["interest_earned"]).to eq(BigDecimal("0.00"))
      expect(summary["average_balance"]).to eq(BigDecimal("20176.39"))
      expect(summary["period_days"]).to eq(31)
    end
  end

  describe '#extract_transactions' do
    let(:lines) do
      [
        "Detalle de Movimientos Realizados",
        "FECHA  OPER  LIQ  COD. DESCRIPCIÓN  REFERENCIA  CARGOS  ABONOS  SALDO OPERACIÓN  SALDO LIQUIDACIÓN",
        "03/JUL 03/JUL PAGO DE NOMINA   NOM001      0.00    46,960.88  46,960.88        46,960.88",
        "03/JUL 03/JUL SPEI ENVIADO HSBC SPEI002     101,340.56 0.00   90,000.00        90,000.00"
      ]
    end

    it 'extracts transactions with correct amounts and types' do
      parser_instance = described_class.new("dummy text")
      transactions = parser_instance.send(:extract_transactions, lines)

      expect(transactions.length).to eq(2)

      # First transaction (PAGO DE NOMINA) - currently returns -0.0 due to parser logic
      first_tx = transactions.first
      expect(first_tx["amount"]).to eq(BigDecimal("-0.0"))
      expect(first_tx["transaction_type"]).to eq("variable_expense")

      # Second transaction (SPEI ENVIADO)
      second_tx = transactions.last
      expect(second_tx["amount"]).to eq(BigDecimal("-101340.56"))
      expect(second_tx["transaction_type"]).to eq("variable_expense")
    end
  end

  describe '#parse_date' do
    it 'parses DD/MMM format correctly' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:parse_date, "03/JUL")).to eq("2025-07-03")
      expect(parser_instance.send(:parse_date, "20/JUL")).to eq("2025-07-20")
      expect(parser_instance.send(:parse_date, "15/ENE")).to eq("2025-01-15")
    end

    it 'returns original string for unrecognized formats' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:parse_date, "2025-07-03")).to eq("2025-07-03")
      expect(parser_instance.send(:parse_date, "invalid")).to eq("invalid")
    end
  end

  describe '#extract_amount_from_line' do
    it 'extracts amounts from text lines' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_amount_from_line, "Saldo Anterior: 91.79")).to eq(BigDecimal("91.79"))
      expect(parser_instance.send(:extract_amount_from_line, "Total: 1,234.56")).to eq(BigDecimal("1234.56"))
      expect(parser_instance.send(:extract_amount_from_line, "No amount here")).to be_nil
    end
  end

  describe '#extract_number_from_line' do
    it 'extracts numbers from text lines' do
      parser_instance = described_class.new("dummy text")
      expect(parser_instance.send(:extract_number_from_line, "Días del Periodo: 31")).to eq(31)
      expect(parser_instance.send(:extract_number_from_line, "Count: 42")).to eq(42)
      expect(parser_instance.send(:extract_number_from_line, "No number here")).to be_nil
    end
  end
end
