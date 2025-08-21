# spec/services/pdf_parser/bbva_savings_account_spec.rb
require 'rails_helper'

RSpec.describe PdfParser::BbvaSavingsAccount do
  let(:parser) { described_class.new }

  describe '#parse' do
    let(:sample_text) do
      <<~TEXT
        BBVA MEXICO
        Estado de Cuenta Libretón Premium
        PAGINA 2 / 7

        No. de Cuenta: 1234567890
        No. de Cliente: 12345678

        Información Financiera
        Rendimiento
        Saldo Promedio: 20,176.39
        Días del Periodo: 31
        Tasa Bruta Anual: 0.000%
        Saldo Promedio Gravable: 0.00
        Intereses a Favor (+): 0.00
        ISR Retenido (-): 0.00

        Comportamiento
        Saldo Anterior: 91.79
        Depósitos / Abonos (+): 11 501,541.87
        Retiros / Cargos (-): 30 491,173.74
        Saldo Final (+): 10,459.92
        Saldo Promedio Mínimo Mensual: 0.00

        Comisiones
        Cheques pagados: 0.00
        Manejo de Cuenta: 0.00
        Total Comisiones: 0.00
        Cargos Objetados: 0.00
        Abonos Objetados: 0.00

        Detalle de Movimientos Realizados
        FECHA  OPER  LIQ  DESCRIPCIÓN                    REFERENCIA  CARGOS    ABONOS    SALDO OPERACIÓN  SALDO LIQUIDACIÓN
        03/JUL 03/JUL PAGO DE NOMINA                     NOM001      0.00      46,960.88  46,960.88        46,960.88
        03/JUL 03/JUL PAGO DE BONO                       BON001      0.00      54,379.68  101,340.56       101,340.56
        03/JUL 03/JUL SPEI RECIBIDOHSBC                   SPEI001     0.00      90,000.00   191,340.56       191,340.56
        03/JUL 03/JUL SPEI ENVIADO HSBC                   SPEI002     101,340.56 0.00       90,000.00        90,000.00
        03/JUL 03/JUL PAGO INTERBANCARIO TDC              TDC001      60,000.00 0.00       30,000.00        30,000.00
        03/JUL 03/JUL PAGO CUENTA DE TERCERO              TERC001     850.00     0.00       29,150.00        29,150.00
        03/JUL 03/JUL SPEI ENVIADO SPIN BY OXXO           SPEI003     1,890.00   0.00       27,260.00        27,260.00
        03/JUL 03/JUL SPEI ENVIADO NU MEXICO              SPEI004     20,000.00  0.00       7,260.00         7,260.00
        04/JUL 04/JUL SPEI ENVIADO BANAMEX                SPEI005     390.00     0.00       6,870.00         6,870.00
        05/JUL 05/JUL SPEI ENVIADO BANAMEX                SPEI006     1,000.00   0.00       5,870.00         5,870.00

        Total de Movimientos
        TOTAL IMPORTE CARGOS: 491,173.74
        TOTAL IMPORTE ABONOS: 501,541.87
        TOTAL MOVIMIENTOS CARGOS: 30
        TOTAL MOVIMIENTOS ABONOS: 11

        Estado de cuenta de Apartados Vigentes
        Folio: PK12345678
        Nombre Apartado    Importe Apartado    Importe Total
        Personal           0.00                $ 0.00
        Proyecto Ejemplo   0.00                $ 0.00
        Ahorro General     0.00                $ 0.00

        BBVA MEXICO, S.A., INSTITUCION DE BANCA MULTIPLE, GRUPO FINANCIERO BBVA MEXICO
        Av. Paseo de la Reforma 510, Col. Juárez, Alcaldía Cuauhtémoc, C.P. 06600, Ciudad de México, México
        R.F.C. BBA830831LJ2
      TEXT
    end

    it 'extracts financial summary correctly' do
      result = parser.parse(sample_text)

      expect(result["financial_summaries"].length).to eq(1)
      summary = result["financial_summaries"].first

      expect(summary["statement_type"]).to eq("savings")
      expect(summary["bank_name"]).to eq("BBVA")
      expect(summary["opening_balance"]).to eq(BigDecimal("91.79"))
      expect(summary["closing_balance"]).to eq(BigDecimal("10459.92"))
      expect(summary["total_deposits"]).to eq(BigDecimal("501541.87"))
      expect(summary["total_withdrawals"]).to eq(BigDecimal("491173.74"))
      expect(summary["interest_earned"]).to eq(BigDecimal("0.00"))
      expect(summary["average_balance"]).to eq(BigDecimal("20176.39"))
      expect(summary["period_days"]).to eq(31)
    end

    it 'extracts transactions correctly' do
      result = parser.parse(sample_text)

      expect(result["transactions"].length).to eq(10)

      # Test first transaction (income)
      first_transaction = result["transactions"].first
      expect(first_transaction["date"]).to eq("2025-07-03")
      expect(first_transaction["description"]).to eq("PAGO DE NOMINA")
      expect(first_transaction["reference"]).to eq("NOM001")
      expect(first_transaction["amount"]).to eq(BigDecimal("46960.88"))
      expect(first_transaction["transaction_type"]).to eq("income")

      # Test expense transaction
      expense_transaction = result["transactions"][3]  # SPEI ENVIADO HSBC
      expect(expense_transaction["date"]).to eq("2025-07-03")
      expect(expense_transaction["description"]).to eq("SPEI ENVIADO HSBC")
      expect(expense_transaction["reference"]).to eq("SPEI002")
      expect(expense_transaction["amount"]).to eq(BigDecimal("-101340.56"))
      expect(expense_transaction["transaction_type"]).to eq("variable_expense")
    end

    it 'handles CARGOS as negative values' do
      result = parser.parse(sample_text)

      # Find a transaction with CARGOS (expenses)
      expense_transaction = result["transactions"].find { |t| t["transaction_type"] == "variable_expense" }
      expect(expense_transaction).to be_present
      expect(expense_transaction["amount"]).to be < 0
    end

    it 'handles ABONOS as positive values' do
      result = parser.parse(sample_text)

      # Find a transaction with ABONOS (income)
      income_transaction = result["transactions"].find { |t| t["transaction_type"] == "income" }
      expect(income_transaction).to be_present
      expect(income_transaction["amount"]).to be > 0
    end

    it 'sets correct extraction source' do
      result = parser.parse(sample_text)
      expect(result["extraction_source"]).to eq("bbva_savings_parser")
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
      summary = parser.send(:extract_financial_summary, lines)

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
        "FECHA  OPER  LIQ  DESCRIPCIÓN  REFERENCIA  CARGOS  ABONOS  SALDO OPERACIÓN  SALDO LIQUIDACIÓN",
        "03/JUL 03/JUL PAGO DE NOMINA   NOM001      0.00    46,960.88  46,960.88        46,960.88",
        "03/JUL 03/JUL SPEI ENVIADO HSBC SPEI002     101,340.56 0.00   90,000.00        90,000.00"
      ]
    end

    it 'extracts transactions with correct amounts and types' do
      transactions = parser.send(:extract_transactions, lines)

      expect(transactions.length).to eq(2)

      # Income transaction
      income_tx = transactions.first
      expect(income_tx["amount"]).to eq(BigDecimal("46960.88"))
      expect(income_tx["transaction_type"]).to eq("income")

      # Expense transaction
      expense_tx = transactions.last
      expect(expense_tx["amount"]).to eq(BigDecimal("-101340.56"))
      expect(expense_tx["transaction_type"]).to eq("variable_expense")
    end
  end

  describe '#parse_date' do
    it 'parses DD/MMM format correctly' do
      expect(parser.send(:parse_date, "03/JUL")).to eq("2025-07-03")
      expect(parser.send(:parse_date, "20/JUL")).to eq("2025-07-20")
      expect(parser.send(:parse_date, "15/ENE")).to eq("2025-01-15")
    end

    it 'returns original string for unrecognized formats' do
      expect(parser.send(:parse_date, "2025-07-03")).to eq("2025-07-03")
      expect(parser.send(:parse_date, "invalid")).to eq("invalid")
    end
  end

  describe '#extract_amount_from_line' do
    it 'extracts amounts from text lines' do
      expect(parser.send(:extract_amount_from_line, "Saldo Anterior: 91.79")).to eq(BigDecimal("91.79"))
      expect(parser.send(:extract_amount_from_line, "Total: 1,234.56")).to eq(BigDecimal("1234.56"))
      expect(parser.send(:extract_amount_from_line, "No amount here")).to be_nil
    end
  end

  describe '#extract_number_from_line' do
    it 'extracts numbers from text lines' do
      expect(parser.send(:extract_number_from_line, "Días del Periodo: 31")).to eq(31)
      expect(parser.send(:extract_number_from_line, "Count: 42")).to eq(42)
      expect(parser.send(:extract_number_from_line, "No number here")).to be_nil
    end
  end
end
