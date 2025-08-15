#!/usr/bin/env ruby

# Debug script for Banorte text filtering
# Run with: rails runner debug_banorte.rb

puts "🔍 Debugging Banorte Text Filtering"
puts "=" * 50

banorte_text = <<~TEXT
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

puts "Original text length: #{banorte_text.length} characters"
puts "\nOriginal text (first 500 chars):"
puts banorte_text[0..500]

puts "\n" + "="*50
puts "Testing line by line filtering:"

lines = banorte_text.split("\n")
lines.each_with_index do |line, index|
  line = line.strip
  next if line.empty?

  # Check if line matches transaction patterns
  transaction_patterns = BankStatementConfig.get_transaction_patterns('banorte')
  transaction_codes = BankStatementConfig.get_transaction_codes('banorte')

  matches_keyword = transaction_patterns.any? { |pattern| line.match?(/#{pattern}/i) }
  matches_code = transaction_codes.any? { |code| line.include?(code) }
  matches_date = line.match?(/\d{2}-[A-Z]{3}-\d{2}/) || line.match?(/\d{2}\/[A-Z]{3}/) || line.match?(/\d{2}-\d{2}-\d{4}/)
  matches_amount = line.match?(/[\d,]+\.\d{2}/)

  status = if matches_keyword || matches_code || matches_date || matches_amount
    "✅ KEEP"
  else
    "❌ FILTER"
  end

  line_num = (index + 1).to_s.rjust(2)
  puts "#{line_num}. #{status} | #{line[0..80]}#{line.length > 80 ? '...' : ''}"
  puts "     Keywords: #{matches_keyword}, Codes: #{matches_code}, Date: #{matches_date}, Amount: #{matches_amount}"
end

puts "\n" + "="*50
puts "Testing full filtering:"

filtered = TransactionTextFilter.filter_for_transactions(banorte_text, bank_name: 'Banorte')
puts "Filtered text length: #{filtered.length} characters"
puts "Reduction: #{((1 - filtered.length.to_f/banorte_text.length) * 100).round(1)}%"

puts "\nFiltered text:"
puts filtered

puts "\n" + "="*50
puts "Testing header extraction:"

headers = TransactionTextFilter.extract_headers(banorte_text, bank_name: 'Banorte')
headers.each do |category, values|
  puts "#{category}: #{values.join(', ')}"
end
