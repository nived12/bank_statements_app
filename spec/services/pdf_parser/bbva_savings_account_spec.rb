# spec/services/pdf_parser/bbva_savings_account_spec.rb
require 'rails_helper'

RSpec.describe PdfParser::BbvaSavingsAccount do
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
        OPER     LIQ   DESCRIPCIÓN                    REFERENCIA                           CARGOS        ABONOS      OPERACIÓN       LIQUIDACIÓN
        03/JUL   03/JUL PAGO DE NOMINA NOM001                                                            46,960.88
        03/JUL   03/JUL PAGO DE BONO BON001                                                              54,379.68
        03/JUL   03/JUL SPEI RECIBIDOHSBC SPEI001                                                        90,000.00
        03/JUL   03/JUL SPEI ENVIADO HSBC SPEI002                                           101,340.56
        03/JUL   03/JUL PAGO INTERBANCARIO TDC TDC001                                     60,000.00
        03/JUL   03/JUL PAGO CUENTA DE TERCERO TERC001                                   850.00
        03/JUL   03/JUL SPEI ENVIADO SPIN BY OXXO SPEI003                                1,890.00
        03/JUL   03/JUL SPEI ENVIADO NU MEXICO SPEI004                                    20,000.00
        04/JUL   04/JUL SPEI ENVIADO BANAMEX SPEI005                                      390.00
        05/JUL   05/JUL SPEI ENVIADO BANAMEX SPEI006                                      1,000.00

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
      result = described_class.call(sample_text)

      expect(result.payload["financial_summaries"].length).to eq(1)
      summary = result.payload["financial_summaries"].first

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
      result = described_class.call(sample_text)

      expect(result.payload["transactions"].length).to eq(10)

      current_year = Date.current.year

      # Test first transaction (income)
      first_transaction = result.payload["transactions"].first
      expect(first_transaction["date"]).to eq("#{current_year}-07-03")
      expect(first_transaction["description"]).to eq("PAGO DE NOMINA")
      expect(first_transaction["reference"]).to eq("NOM001")
      expect(first_transaction["amount"]).to eq(BigDecimal("46960.88"))
      expect(first_transaction["transaction_type"]).to eq("income")

      # Test expense transaction
      expense_transaction = result.payload["transactions"][3]  # SPEI ENVIADO HSBC
      expect(expense_transaction["date"]).to eq("#{current_year}-07-03")
      expect(expense_transaction["description"]).to eq("SPEI ENVIADO HSBC")
      expect(expense_transaction["reference"]).to eq("SPEI002")
      expect(expense_transaction["amount"]).to eq(BigDecimal("-101340.56"))
      expect(expense_transaction["transaction_type"]).to eq("variable_expense")
    end

    it 'handles CARGOS as negative values' do
      result = described_class.call(sample_text)

      # Find a transaction with CARGOS (expenses)
      expense_transaction = result.payload["transactions"].find do |t|
        t["transaction_type"] == "variable_expense"
      end
      expect(expense_transaction).to be_present
      expect(expense_transaction["amount"]).to be < 0
    end

    it 'handles ABONOS as positive values' do
      result = described_class.call(sample_text)

      # Find a transaction with ABONOS (income)
      income_transaction = result.payload["transactions"].find { |t| t["transaction_type"] == "income" }
      expect(income_transaction).to be_present
      expect(income_transaction["amount"]).to be > 0
    end

    it 'sets correct extraction source' do
      result = described_class.call(sample_text)
      expect(result.payload["extraction_source"]).to eq("bbva_savings_parser")
    end
  end
end
