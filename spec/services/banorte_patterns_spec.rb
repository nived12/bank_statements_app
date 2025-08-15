require 'rails_helper'

RSpec.describe "Banorte Statement Patterns" do
  let(:banorte_text) do
    <<~TEXT
      ESTADO DE CUENTA / NOMINA BANORTE SIN CHEQUERA
      BANORTE

      INFORMACIÓN DEL PERIODO
      Periodo: Del 11/Junio/2025 al 10/Julio/2025
      Fecha de corte: 10/Julio/2025
      Moneda: PESOS

      NO. DE CLIENTE: 76672439
      RFC: GUTD980526730
      SUCURSAL: 0051 MONTERREY GRAN PLAZA
      PLAZA: 9850 PLAZA NUEVO LEON
      DIRECCIÓN: ZARAGOZA SUR ESQ. MORELOS 920 CENTRO
      TELÉFONO: 3195200

      RESUMEN INTEGRAL
      Producto: NOMINA BANORTE SIN CHEQUERA
      No. de Cuenta: 1306500708
      CLABE: 072 580 01306500708 8
      Saldo anterior: $817.32
      Saldo al corte: $855.44

      DETALLE DE MOVIMIENTOS (PESOS)▼
      Nomina Banorte Sin Chequera

      FECHA | DESCRIPCIÓN / ESTABLECIMIENTO | MONTO DEL DEPOSITO | MONTO DEL RETIRO | SALDO
      10-JUN-25 | SALDO ANTERIOR | | | 817.32
      11-JUN-25 | DEPOSITO NOMINA LINEA 40421 | 2,800.00 | | 3,617.32
      02-JUL-25 | COMPRA ORDEN DE PAGO SPEI 0250611=REFERENCIA CTA/CLABE: 012580015633591557, BEC SPEI BCO:012 BENEF:NO INGRESAD (DATO NO VERIF POR ESTA INST), Gaby botella CVE RASTREO: 38432P06202506114147089611 RFC: ND IVA:. 0 BBVA MEXICO HORA LIQ: 15:20:19 | | 3,712.88 | -95.56
      02-JUL-25 | TRASP FONDOS 0000250704 IVA:. 0, A LA CUENTA: 4189143135459967 Tacos AL R.F.C. BEEA800601QK5 | | 500.00 | -595.56

      Saldo Promedio: En el Periodo 01 Jun al 30 Jun: $4,242.88
      Intereses devengados: Tasa Bruta Anual: 0.00%
      Saldo no disponible al día: Comisiones pendientes de aplicar: $500.00

      Advertencia: Incumplir tus obligaciones te puede generar comisiones.
      En Banorte estamos para servirte en Banortel: Ciudad de México: (55) 5140 5600
      Banco Mercantil del Norte S.A. Institución de Banca Múltiple Grupo Financiero Banorte
      PAGINA 1/4
    TEXT
  end

  describe "TransactionTextFilter with Banorte" do
    it "filters out non-transaction content" do
      filtered = TransactionTextFilter.filter_for_transactions(banorte_text, bank_name: 'Banorte')

      # Should keep transaction lines
      expect(filtered).to include('10-JUN-25 | SALDO ANTERIOR | | | 817.32')
      expect(filtered).to include('11-JUN-25 | DEPOSITO NOMINA LINEA 40421 | 2,800.00 | | 3,617.32')
      expect(filtered).to include('02-JUL-25 | COMPRA ORDEN DE PAGO SPEI')
      expect(filtered).to include('02-JUL-25 | TRASP FONDOS 0000250704')

      # Should filter out header/footer content
      expect(filtered).not_to include('ESTADO DE CUENTA / NOMINA BANORTE SIN CHEQUERA')
      expect(filtered).not_to include('BANORTE')
      expect(filtered).not_to include('INFORMACIÓN DEL PERIODO')
      expect(filtered).not_to include('NO. DE CLIENTE: 76672439')
      expect(filtered).not_to include('Saldo Promedio:')
      expect(filtered).not_to include('Advertencia:')
      expect(filtered).not_to include('En Banorte estamos para servirte en Banortel:')
      expect(filtered).not_to include('PAGINA 1/4')
    end

    it "extracts headers correctly" do
      headers = TransactionTextFilter.extract_headers(banorte_text, bank_name: 'Banorte')

      expect(headers['account_info']).to include('76672439')  # Client number
      expect(headers['account_info']).to include('GUTD980526730')  # RFC
      expect(headers['account_info']).to include('0051 MONTERREY GRAN PLAZA')  # Branch
      expect(headers['account_info']).to include('9850 PLAZA NUEVO LEON')  # Plaza

      expect(headers['statement_period']).to include('Del 11/Junio/2025 al 10/Julio/2025')
      expect(headers['statement_period']).to include('10/Julio/2025')

      expect(headers['balance_info']).to include('817.32')  # Previous balance
      expect(headers['balance_info']).to include('855.44')  # Current balance
      expect(headers['balance_info']).to include('4,242.88')  # Average balance

      expect(headers['account_details']).to include('1306500708')  # Account number
      expect(headers['account_details']).to include('072 580 01306500708 8')  # CLABE
      expect(headers['account_details']).to include('NOMINA BANORTE SIN CHEQUERA')  # Product
    end
  end

  describe "BankStatementConfig with Banorte" do
    let(:config) { BankStatementConfig.instance }

    it "returns Banorte configuration" do
      banorte_config = config.bank_config('banorte')
      expect(banorte_config).to be_present
      expect(banorte_config['name']).to eq('Banorte')
    end

    it "returns Banorte transaction patterns" do
      patterns = config.get_transaction_patterns('banorte')
      expect(patterns).to include('DEPOSITO NOMINA')
      expect(patterns).to include('COMPRA ORDEN DE PAGO')
      expect(patterns).to include('TRASP FONDOS')
      expect(patterns).to include('SPEI')
    end

    it "returns Banorte non-transaction patterns" do
      patterns = config.get_non_transaction_patterns('banorte')
      expect(patterns).to include('ESTADO DE CUENTA / NOMINA BANORTE SIN CHEQUERA')
      expect(patterns).to include('BANORTE')
      expect(patterns).to include('INFORMACIÓN DEL PERIODO')
      expect(patterns).to include('Saldo Promedio')
    end

    it "returns Banorte transaction codes" do
      codes = config.get_transaction_codes('banorte')
      expect(codes).to include('SPEI')
      expect(codes).to include('REFERENCIA CTA/CLABE')
      expect(codes).to include('CVE RASTREO')
      expect(codes).to include('HORA LIQ')
    end

    it "returns Banorte date patterns" do
      patterns = config.get_date_patterns('banorte')
      expect(patterns).to include('DD-MMM-YY')
      expect(patterns).to include('DD MMM al DD MMM')
    end

    it "returns Banorte amount columns" do
      columns = config.get_amount_columns('banorte')
      expect(columns).to include('MONTO DEL DEPOSITO')
      expect(columns).to include('MONTO DEL RETIRO')
      expect(columns).to include('SALDO')
      expect(columns).to include('Saldo anterior')
    end
  end
end
