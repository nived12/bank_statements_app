# spec/services/pdf_parser/bbva_credit_card_spec.rb
require "rails_helper"

RSpec.describe PdfParser::BbvaCreditCard do
  let(:parser) { described_class.new }

  describe "#parse" do
    context "with comprehensive BBVA credit card statement" do
      let(:text) do
        <<~TEXT
          BBVA MEXICO, S.A., INSTITUCION DE BANCA MULTIPLE, GRUPO FINANCIERO BBVA MEXICO
          Estado de Cuenta Tarjeta Oro BBVA PAGINA 3/6

          JUAN PEREZ GONZALEZ
          No. de Tarjeta: 1234 5678 9012 3456
          No. de Cliente: 12345678

          Generados: 424
          Utilizados: 0
          Vencidos: 0
          Saldo Nuevo: 1,310

          Movimientos Efectuados
          Tarjeta Titular 1234 5678 9012 3456

          FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
          21/01/24 | 22/01/24 | BMOVIL.PAGO TDC | | | | 3,111.81
          Iva: $ 184.16 Interes: $0.00 Comisiones: $ 383.66 Capital: $ 2,543.99 Capital de promoción:$0.00 Pago excedente:$ 0.00
          17/02/24 | 19/02/24 | 300843361 SIX PREMIER | CNC 820428674 | ******7465 | 385.00 |
          17/02/24 | 19/02/24 | 300843361 SIX PREMIER | CNC 820428674 | ******2573 | 46.00 |
          17/02/24 | 19/02/24 | 300843361 SIX PREMIER | CNC 820428674 | ******0916 | 188.00 |
          20/02/24 | 20/02/24 | 02 DE 03 ANUALIDAD | | | 383.66 |

          TOTAL IMPORTES: Cargos: $619.00, Abonos: $3,111.81

          Tarjeta Titular 9876 5432 1098 7654

          FECHA AUTORIZACION | FECHA APLICACION | CONCEPTO | R.F.C. | REFERENCIA | IMPORTE CARGOS | IMPORTE ABONOS
          22/01/24 | 23/01/24 | BESTBUYCOM806908729635 USD $108.24 TIPO DE CAMBIO $17.20 | | ******3128 | 1,861.52 |
          22/01/24 | 23/01/24 | BESTBUYCOM806908729635 USD $21.64 TIPO DE CAMBIO $17.20 | | ******9447 | 372.17 |
          26/01/24 | 29/01/24 | NETFLIX COM 1 | NME 110513P13 | ******2552 | 219.00 |
          04/02/24 | 06/02/24 | Google YouTubePremium MXP $139.00 TIPO DE CAMBIO $1.00 | | ******5069 | 139.00 |
          05/02/24 | 06/02/24 | STR*PLAYTOMIC IO A5FB3 | SPM 1410037E8 | ******1533 | 260.00 |
          09/02/24 | 12/02/24 | AMAZON MX | ANE 140618P37 | ******1124 | 119.00 |
          12/02/24 | 13/02/24 | AMAZON PRIME | ANE 140618P37 | ******7665 | 99.00 |
          16/02/24 | 19/02/24 | MERPAGO*MELIMAS | MAG 2105031W3 | ******0849 | 129.90 |

          TOTAL IMPORTES: $3,856.19

          Tarjeta Titular 1234 5678 9012 3456 (continued)

          16/02/24 | 19/02/24 | CONEKTA*PARCO | CTE 160222123 | ******6510 | 40.60 |
          20/02/24 | 21/02/24 | 07 DE 12 VIVA AEROBUS CIB | | | 343.00 |
          20/02/24 | 21/02/24 | 02 DE 12 SRIA FINANZAS TES 1 M | | | 273.00 |

          TOTAL IMPORTES: $3,856.19

          Resumen Informativo de sus Cargos sin Intereses
          FECHA TRANSACCION | NOMBRE DEL CARGO | CARGO INICIAL | PARCIALIDAD | FALTAN | SALDO ACTUAL
          20/02/24 | COMISION ANUALIDAD | 1,151.00 | 383.66 | 01 de 03 | 383.68
          31/07/23 | VIVA AEROBUS CIB | 4,106.07 | 343.00 | 05 de 12 | 1,705.07
          02/01/24 | SRIA FINANZAS TES 1 MU | 3,268.00 | 273.00 | 10 de 12 | 2,722.00

          Total de Parcialidades Incluido en su Saldo: $999.66
          Total Saldo Actual Incluido en Saldo Nuevo: $4,810.75

          Resumen Informativo de Beneficios
          Detalle de Transacciones de Beneficios

          Si te uniste al Plan de Apoyo Otis, te recordamos que puedes consultar los terminos y condiciones en bbva.mx/apoyo-guerrero
        TEXT
      end

      it "extracts all 16 transactions correctly" do
        result = parser.parse(text)

        # Debug: Print all extracted transactions
        puts "\n=== DEBUG: Extracted Transactions ==="
        result["transactions"].each_with_index do |tx, i|
          puts "#{i+1}. #{tx['date']} | #{tx['description']} | #{tx['amount']} | #{tx['transaction_type']}"
        end
        puts "Total: #{result['transactions'].length}"
        puts "=====================================\n"

        expect(result["transactions"].length).to eq(16)
        expect(result["extraction_source"]).to eq("bbva_credit_card_parser_deterministic_fallback")

        # Verify all expected transactions are present
        transaction_descriptions = result["transactions"].map { |t| t["description"] }

        # Card 1 transactions
        expect(transaction_descriptions).to include("BMOVIL.PAGO TDC")
        expect(transaction_descriptions).to include("300843361 SIX PREMIER")
        expect(transaction_descriptions).to include("02 DE 03 ANUALIDAD")

        # Card 2 transactions
        expect(transaction_descriptions).to include("BESTBUYCOM806908729635 USD $108.24 TIPO DE CAMBIO $17.20")
        expect(transaction_descriptions).to include("BESTBUYCOM806908729635 USD $21.64 TIPO DE CAMBIO $17.20")
        expect(transaction_descriptions).to include("NETFLIX COM 1")
        expect(transaction_descriptions).to include("Google YouTubePremium MXP $139.00 TIPO DE CAMBIO $1.00")
        expect(transaction_descriptions).to include("STR*PLAYTOMIC IO A5FB3")
        expect(transaction_descriptions).to include("AMAZON MX")
        expect(transaction_descriptions).to include("AMAZON PRIME")
        expect(transaction_descriptions).to include("MERPAGO*MELIMAS")

        # Additional card 1 transactions
        expect(transaction_descriptions).to include("CONEKTA*PARCO")
        expect(transaction_descriptions).to include("07 DE 12 VIVA AEROBUS CIB")
        expect(transaction_descriptions).to include("02 DE 12 SRIA FINANZAS TES 1 M")
      end

      it "correctly handles payment transaction (BMOVIL.PAGO TDC)" do
        result = parser.parse(text)

        payment_tx = result["transactions"].find { |t| t["description"].include?("BMOVIL.PAGO TDC") }
        expect(payment_tx).to be_present

        expect(payment_tx["date"]).to eq("2024-01-21")
        expect(payment_tx["amount"]).to eq("3111.81")
        expect(payment_tx["transaction_type"]).to eq("income")
        expect(payment_tx["bank_entry_type"]).to eq("credit")
        expect(payment_tx["merchant"]).to eq("BMOVIL")
        expect(payment_tx["reference"]).to be_nil
      end

      it "correctly handles SIX PREMIER transactions" do
        result = parser.parse(text)

        six_premier_txs = result["transactions"].select { |t| t["description"].include?("SIX PREMIER") }
        expect(six_premier_txs.length).to eq(3)

        six_premier_txs.each do |tx|
          expect(tx["date"]).to eq("2024-02-17")
          expect(tx["transaction_type"]).to eq("variable_expense")
          expect(tx["bank_entry_type"]).to eq("debit")
          expect(tx["merchant"]).to eq("SIX PREMIER")
          expect(tx["rfc"]).to eq("CNC 820428674")
          expect(tx["reference"]).to be_present
        end

        # Check specific amounts
        amounts = six_premier_txs.map { |t| t["amount"].to_f.abs }.sort
        expect(amounts).to eq([ 46.0, 188.0, 385.0 ])
      end

      it "correctly handles annual fee transaction" do
        result = parser.parse(text)

        annual_fee_tx = result["transactions"].find { |t| t["description"].include?("ANUALIDAD") }
        expect(annual_fee_tx).to be_present

        expect(annual_fee_tx["date"]).to eq("2024-02-20")
        expect(annual_fee_tx["amount"]).to eq("-383.66")
        expect(annual_fee_tx["transaction_type"]).to eq("variable_expense")
        expect(annual_fee_tx["bank_entry_type"]).to eq("debit")
        expect(annual_fee_tx["merchant"]).to eq("BBVA")
      end

      it "correctly handles BESTBUY transactions with foreign currency" do
        result = parser.parse(text)

        bestbuy_txs = result["transactions"].select { |t| t["description"].include?("BESTBUY") }
        expect(bestbuy_txs.length).to eq(2)

        bestbuy_txs.each do |tx|
          expect(tx["date"]).to eq("2024-01-22")
          expect(tx["transaction_type"]).to eq("variable_expense")
          expect(tx["bank_entry_type"]).to eq("debit")
          expect(tx["merchant"]).to eq("BESTBUY")
          expect(tx["reference"]).to eq("806908729635")
        end

        # Check specific amounts
        amounts = bestbuy_txs.map { |t| t["amount"].to_f.abs }.sort
        expect(amounts).to eq([ 372.17, 1861.52 ])
      end

      it "correctly handles streaming service transactions" do
        result = parser.parse(text)

        netflix_tx = result["transactions"].find { |t| t["description"].include?("NETFLIX") }
        expect(netflix_tx).to be_present
        expect(netflix_tx["date"]).to eq("2024-01-26")
        expect(netflix_tx["amount"]).to eq("-219.00")
        expect(netflix_tx["transaction_type"]).to eq("variable_expense")
        expect(netflix_tx["merchant"]).to eq("NETFLIX")
        expect(netflix_tx["rfc"]).to eq("NME 110513P13")

        youtube_tx = result["transactions"].find { |t| t["description"].include?("YouTubePremium") }
        expect(youtube_tx).to be_present
        expect(youtube_tx["date"]).to eq("2024-02-04")
        expect(youtube_tx["amount"]).to eq("-139.00")
        expect(youtube_tx["transaction_type"]).to eq("variable_expense")
        expect(youtube_tx["merchant"]).to eq("GOOGLE")
      end

      it "correctly handles gaming and entertainment transactions" do
        result = parser.parse(text)

        playtomic_tx = result["transactions"].find { |t| t["description"].include?("PLAYTOMIC") }
        expect(playtomic_tx).to be_present
        expect(playtomic_tx["date"]).to eq("2024-02-05")
        expect(playtomic_tx["amount"]).to eq("-260.00")
        expect(playtomic_tx["transaction_type"]).to eq("variable_expense")
        expect(playtomic_tx["merchant"]).to eq("PLAYTOMIC")
        expect(playtomic_tx["rfc"]).to eq("SPM 1410037E8")
        expect(playtomic_tx["reference"]).to eq("A5FB3")
      end

      it "correctly handles Amazon transactions" do
        result = parser.parse(text)

        amazon_txs = result["transactions"].select { |t| t["description"].include?("AMAZON") }
        expect(amazon_txs.length).to eq(2)

        amazon_mx_tx = amazon_txs.find { |t| t["description"].include?("AMAZON MX") }
        expect(amazon_mx_tx["date"]).to eq("2024-02-09")
        expect(amazon_mx_tx["amount"]).to eq("-119.00")
        expect(amazon_mx_tx["merchant"]).to eq("AMAZON")
        expect(amazon_mx_tx["rfc"]).to eq("ANE 140618P37")

        amazon_prime_tx = amazon_txs.find { |t| t["description"].include?("AMAZON PRIME") }
        expect(amazon_prime_tx["date"]).to eq("2024-02-12")
        expect(amazon_prime_tx["amount"]).to eq("-99.00")
        expect(amazon_prime_tx["merchant"]).to eq("AMAZON")
        expect(amazon_prime_tx["rfc"]).to eq("ANE 140618P37")
      end

      it "correctly handles other merchant transactions" do
        result = parser.parse(text)

        melimas_tx = result["transactions"].find { |t| t["description"].include?("MELIMAS") }
        expect(melimas_tx).to be_present
        expect(melimas_tx["date"]).to eq("2024-02-16")
        expect(melimas_tx["amount"]).to eq("-129.90")
        expect(melimas_tx["merchant"]).to eq("MELIMAS")
        expect(melimas_tx["rfc"]).to eq("MAG 2105031W3")

        parco_tx = result["transactions"].find { |t| t["description"].include?("PARCO") }
        expect(parco_tx).to be_present
        expect(parco_tx["date"]).to eq("2024-02-16")
        expect(parco_tx["amount"]).to eq("-40.60")
        expect(parco_tx["merchant"]).to eq("PARCO")
        expect(parco_tx["rfc"]).to eq("CTE 160222123")
      end

      it "correctly handles installment transactions" do
        result = parser.parse(text)

        viva_tx = result["transactions"].find { |t| t["description"].include?("VIVA AEROBUS") }
        expect(viva_tx).to be_present
        expect(viva_tx["date"]).to eq("2024-02-20")
        expect(viva_tx["amount"]).to eq("-343.00")
        expect(viva_tx["merchant"]).to eq("VIVA AEROBUS")

        finanzas_tx = result["transactions"].find { |t| t["description"].include?("SRIA FINANZAS") }
        expect(finanzas_tx).to be_present
        expect(finanzas_tx["date"]).to eq("2024-02-20")
        expect(finanzas_tx["amount"]).to eq("-273.00")
        expect(finanzas_tx["merchant"]).to eq("SRIA FINANZAS")
      end

      it "excludes non-transaction summary sections" do
        result = parser.parse(text)

        # Should not include summary lines
        summary_lines = result["transactions"].select { |t| t["description"].include?("TOTAL IMPORTES") }
        expect(summary_lines).to be_empty

        # Should not include installment summary lines
        installment_lines = result["transactions"].select { |t| t["description"].include?("COMISION ANUALIDAD") && t["description"].include?("01 de 03") }
        expect(installment_lines).to be_empty

        # Should not include benefit summary lines
        benefit_lines = result["transactions"].select { |t| t["description"].include?("Resumen Informativo") }
        expect(benefit_lines).to be_empty
      end

      it "correctly assigns transaction types based on Spanish banking terms" do
        result = parser.parse(text)

        # All CARGOS should be negative (expenses)
        cargos_txs = result["transactions"].select { |t| t["raw_text"]&.include?("IMPORTE CARGOS") }
        cargos_txs.each do |tx|
          expect(tx["amount"].to_f).to be < 0
          expect(tx["transaction_type"]).to eq("variable_expense")
          expect(tx["bank_entry_type"]).to eq("debit")
        end

        # All ABONOS should be positive (income)
        abonos_txs = result["transactions"].select { |t| t["raw_text"]&.include?("IMPORTE ABONOS") }
        abonos_txs.each do |tx|
          expect(tx["amount"].to_f).to be > 0
          expect(tx["transaction_type"]).to eq("income")
          expect(tx["bank_entry_type"]).to eq("credit")
        end
      end

      it "extracts references correctly for various transaction types" do
        result = parser.parse(text)

        # Check for specific reference patterns
        six_premier_refs = result["transactions"].select { |t| t["description"].include?("SIX PREMIER") }.map { |t| t["reference"] }
        expect(six_premier_refs).to include("300843361")

        bestbuy_refs = result["transactions"].select { |t| t["description"].include?("BESTBUY") }.map { |t| t["reference"] }
        expect(bestbuy_refs).to all(eq("806908729635"))

        playtomic_ref = result["transactions"].find { |t| t["description"].include?("PLAYTOMIC") }["reference"]
        expect(playtomic_ref).to eq("A5FB3")

        # Check masked references
        masked_refs = result["transactions"].select { |t| t["reference"]&.start_with?("******") }
        expect(masked_refs.length).to be > 0
      end

      it "handles date format correctly for all transactions" do
        result = parser.parse(text)

        # All dates should be in YYYY-MM-DD format
        result["transactions"].each do |tx|
          expect(tx["date"]).to match(/\A\d{4}-\d{2}-\d{2}\z/)
        end

        # Check specific dates
        expect(result["transactions"].find { |t| t["description"].include?("BMOVIL") }["date"]).to eq("2024-01-21")
        expect(result["transactions"].find { |t| t["description"].include?("SIX PREMIER") }["date"]).to eq("2024-02-17")
        expect(result["transactions"].find { |t| t["description"].include?("ANUALIDAD") }["date"]).to eq("2024-02-20")
        expect(result["transactions"].find { |t| t["description"].include?("BESTBUY") }["date"]).to eq("2024-01-22")
      end

      it "extracts RFC information when available" do
        result = parser.parse(text)

        # Check transactions with RFC
        rfc_transactions = result["transactions"].select { |t| t["rfc"].present? }
        expect(rfc_transactions.length).to be > 0

        # Check specific RFCs
        six_premier_rfc = result["transactions"].find { |t| t["description"].include?("SIX PREMIER") }["rfc"]
        expect(six_premier_rfc).to eq("CNC 820428674")

        netflix_rfc = result["transactions"].find { |t| t["description"].include?("NETFLIX") }["rfc"]
        expect(netflix_rfc).to eq("NME 110513P13")
      end
    end

    context "with minimal text" do
      let(:text) { "21/01/24 BMOVIL.PAGO TDC IMPORTE ABONOS: 3,111.81" }

      it "extracts single transaction" do
        result = parser.parse(text)

        expect(result["transactions"].length).to eq(1)
        tx = result["transactions"].first

        expect(tx["date"]).to eq("2024-01-21")
        expect(tx["description"]).to eq("BMOVIL.PAGO TDC")
        expect(tx["amount"]).to eq("3111.81")
        expect(tx["transaction_type"]).to eq("income")
        expect(tx["bank_entry_type"]).to eq("credit")
        expect(tx["merchant"]).to eq("BMOVIL")
      end
    end

    context "with no transactions" do
      let(:text) { "Estado de Cuenta BBVA\nNo transactions found" }

      it "returns empty transactions array" do
        result = parser.parse(text)

        expect(result["transactions"]).to be_empty
        expect(result["extraction_source"]).to eq("bbva_credit_card_parser")
      end
    end

    context "with installment summary section" do
      let(:text) do
        <<~TEXT
          Resumen Informativo de sus Cargos sin Intereses
          FECHA TRANSACCION | NOMBRE DEL CARGO | CARGO INICIAL | PARCIALIDAD | FALTAN | SALDO ACTUAL
          20/02/24 | COMISION ANUALIDAD | 1,151.00 | 383.66 | 01 de 03 | 383.68
          31/07/23 | VIVA AEROBUS CIB | 4,106.07 | 343.00 | 05 de 12 | 1,705.07

          Total de Parcialidades Incluido en su Saldo: $999.66
        TEXT
      end

      it "excludes installment summary lines from transactions" do
        result = parser.parse(text)

        expect(result["transactions"]).to be_empty
        expect(result["extraction_source"]).to eq("bbva_credit_card_parser")
      end
    end
  end
end
