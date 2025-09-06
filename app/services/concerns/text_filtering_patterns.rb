# frozen_string_literal: true

##
# TextFilteringPatterns
# Concern module for bank-specific text filtering patterns and logic
#
# Usage:
# include TextFilteringPatterns in your service class and you can use:
#   patterns = get_patterns_for_bank(bank_type)
#   should_keep = should_keep_line?(line, patterns, bank_type)
#
module TextFilteringPatterns
  private

  def get_patterns_for_bank(bank_type)
    case bank_type
    when "bbva"
      {
        transaction: [
          /\d{2}-[a-z]{3}-\d{4}/,  # Date format: DD-MMM-YYYY
          /[+\-]\s*\$?\s*[\d,]+\.\d{2}/,  # Amount with sign
          /\b[A-Z\s]{3,}\b/  # Transaction descriptions
        ],
        codes: [
          /\b[A-Z]{2,4}\d{2,4}\b/,  # Transaction codes
          /\b\d{4}\s*[A-Z]{2,4}\b/  # Reference numbers
        ],
        non_transaction: [
          /^Saldo (Promedio|Final):\s*[\d,]+\.\d{2}$/i,
          /^Total (Movimientos|Transacciones):\s*\d+$/i,
          /^Fecha de Corte:/i,
          /^Fecha de Pago:/i
        ],
        strong: [
          /^Página\s+\d+$/i,
          /^BBVA\s+Bancomer/i,
          /^Estado de Cuenta/i,
          /^Resumen de Movimientos/i
        ]
      }
    when "santander"
      {
        transaction: [
          /\d{2}\/\d{2}\/\d{4}/,  # Date format: DD/MM/YYYY
          /[+\-]\s*\$?\s*[\d,]+\.\d{2}/,  # Amount with sign
          /\b[A-Z\s]{3,}\b/  # Transaction descriptions
        ],
        codes: [
          /\b[A-Z]{2,4}\d{2,4}\b/,  # Transaction codes
          /\b\d{4}\s*[A-Z]{2,4}\b/  # Reference numbers
        ],
        non_transaction: [
          /^Saldo (Anterior|Actual):\s*[\d,]+\.\d{2}$/i,
          /^Total (Movimientos|Transacciones):\s*\d+$/i,
          /^Fecha de Corte:/i
        ],
        strong: [
          /^Página\s+\d+$/i,
          /^Banco Santander/i,
          /^Estado de Cuenta/i,
          /^Resumen de Movimientos/i
        ]
      }
    when "banorte"
      {
        transaction: [
          /\d{2}-\d{2}-\d{4}/,  # Date format: DD-MM-YYYY
          /[+\-]\s*\$?\s*[\d,]+\.\d{2}/,  # Amount with sign
          /\b[A-Z\s]{3,}\b/  # Transaction descriptions
        ],
        codes: [
          /\b[A-Z]{2,4}\d{2,4}\b/,  # Transaction codes
          /\b\d{4}\s*[A-Z]{2,4}\b/  # Reference numbers
        ],
        non_transaction: [
          /^Saldo (Anterior|Actual):\s*[\d,]+\.\d{2}$/i,
          /^Total (Movimientos|Transacciones):\s*\d+$/i,
          /^Fecha de Corte:/i
        ],
        strong: [
          /^Página\s+\d+$/i,
          /^Banorte/i,
          /^Estado de Cuenta/i,
          /^Resumen de Movimientos/i
        ]
      }
    when "banamex"
      {
        transaction: [
          /\d{2}\/\d{2}\/\d{4}/,  # Date format: DD/MM/YYYY
          /[+\-]\s*\$?\s*[\d,]+\.\d{2}/,  # Amount with sign
          /\b[A-Z\s]{3,}\b/  # Transaction descriptions
        ],
        codes: [
          /\b[A-Z]{2,4}\d{2,4}\b/,  # Transaction codes
          /\b\d{4}\s*[A-Z]{2,4}\b/  # Reference numbers
        ],
        non_transaction: [
          /^Saldo (Anterior|Actual):\s*[\d,]+\.\d{2}$/i,
          /^Total (Movimientos|Transacciones):\s*\d+$/i,
          /^Fecha de Corte:/i
        ],
        strong: [
          /^Página\s+\d+$/i,
          /^Banamex/i,
          /^Estado de Cuenta/i,
          /^Resumen de Movimientos/i
        ]
      }
    else
      # Generic patterns for unknown banks
      {
        transaction: [
          /\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/,  # Generic date format
          /[+\-]\s*\$?\s*[\d,]+\.?\d*/,  # Generic amount format
          /\b[A-Z\s]{3,}\b/  # Generic transaction descriptions
        ],
        codes: [
          /\b[A-Z]{2,4}\d{2,4}\b/,  # Generic transaction codes
          /\b\d{4}\s*[A-Z]{2,4}\b/  # Generic reference numbers
        ],
        non_transaction: [
          /^Saldo (Anterior|Actual|Final):\s*[\d,]+\.?\d*$/i,
          /^Total (Movimientos|Transacciones):\s*\d+$/i,
          /^Fecha de Corte:/i
        ],
        strong: [
          /^Página\s+\d+$/i,
          /^Estado de Cuenta/i,
          /^Resumen de Movimientos/i
        ]
      }
    end
  end

  def should_keep_line?(line, patterns, bank_type)
    # Check if line matches transaction patterns
    return true if patterns[:transaction].any? { |pattern| line.match?(pattern) }
    return true if patterns[:codes].any? { |pattern| line.match?(pattern) }

    # Check if line should be filtered out
    return false if patterns[:non_transaction].any? { |pattern| line.match?(pattern) }
    return false if patterns[:strong].any? { |pattern| line.match?(pattern) }

    # Check if it's a potential transaction line
    is_potential_transaction_line?(line, bank_type)
  end

  def is_transaction_continuation?(line, filtered_lines, bank_type)
    return false if filtered_lines.empty?

    last_line = filtered_lines.last

    # Check if this line continues the previous transaction
    case bank_type
    when "bbva"
      # BBVA specific continuation logic
      line.match?(/^\s*[A-Z\s]+$/) && last_line.match?(/\d{2}-[a-z]{3}-\d{4}/)
    when "santander"
      # Santander specific continuation logic
      line.match?(/^\s*[A-Z\s]+$/) && last_line.match?(/\d{2}\/\d{2}\/\d{4}/)
    when "banorte"
      # Banorte specific continuation logic
      line.match?(/^\s*[A-Z\s]+$/) && last_line.match?(/\d{2}-\d{2}-\d{4}/)
    when "banamex"
      # Banamex specific continuation logic
      line.match?(/^\s*[A-Z\s]+$/) && last_line.match?(/\d{2}\/\d{2}\/\d{4}/)
    else
      # Generic continuation logic
      line.match?(/^\s*[A-Z\s]+$/) && last_line.match?(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/)
    end
  end

  def is_potential_transaction_line?(line, bank_type)
    case bank_type
    when "bbva"
      line.match?(/\d{2}-[a-z]{3}-\d{4}/) && line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
    when "santander"
      line.match?(/\d{2}\/\d{2}\/\d{4}/) && line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
    when "banorte"
      line.match?(/\d{2}-\d{2}-\d{4}/) && line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
    when "banamex"
      line.match?(/\d{2}\/\d{2}\/\d{4}/) && line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
    else
      # Generic transaction line detection
      line.match?(/\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}/) && line.match?(/[+\-]\s*\$?\s*[\d,]+\.\d{2}/)
    end
  end
end
