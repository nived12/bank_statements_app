# app/services/pdf_parser/concerns/financial_summary_extraction.rb
module PdfParser
  module Concerns
    module FinancialSummaryExtraction
      extend ActiveSupport::Concern

      private

      def extract_financial_summary_base(lines, bank_name)
        summary = {
          "statement_type" => "savings",
          "bank_name" => bank_name
        }

        # Look for statement period
        period_info = extract_statement_period(lines)
        summary.merge!(period_info) if period_info

        # Look for opening and closing balances
        lines.each do |line|
          # Look for opening balance patterns
          if line.match?(/SALDO\s+ANTERIOR|SALDO\s+INICIAL/i)
            amount = extract_amount_from_line(line)
            summary["opening_balance"] = amount if amount
          end

          # Look for closing balance patterns
          if line.match?(/SALDO\s+FINAL|SALDO\s+ACTUAL/i)
            amount = extract_amount_from_line(line)
            summary["closing_balance"] = amount if amount
          end

          # Look for total deposits
          if line.match?(/TOTAL\s+DEPOSITOS|TOTAL\s+ABONOS|Depósitos\s+\/\s+Abonos/i)
            amount = extract_amount_from_line(line)
            summary["total_deposits"] = amount if amount
          end

          # Look for total withdrawals
          if line.match?(/TOTAL\s+RETIROS|TOTAL\s+CARGOS|Retiros\s+\/\s+Cargos/i)
            amount = extract_amount_from_line(line)
            summary["total_withdrawals"] = amount if amount
          end

          # Look for interest earned
          if line.match?(/Intereses\s+a\s+Favor/i)
            amount = extract_amount_from_line(line)
            summary["interest_earned"] = amount if amount
          end

          # Look for average balance
          if line.match?(/^Saldo\s+Promedio:\s*[\d,]+\.\d{2}/)
            amount = extract_amount_from_line(line)
            summary["average_balance"] = amount if amount
          end

          # Look for period days
          if line.match?(/Días\s+del\s+Periodo/i)
            days = extract_number_from_line(line)
            summary["period_days"] = days if days
          end
        end

        summary
      end

      def extract_statement_period(lines)
        period_info = {}

        lines.each do |line|
          if line.include?("PERIODO") || line.include?("Periodo")
            # Extract the full period description
            period_info["period_description"] = line.split(/PERIODO|Periodo/).last&.strip

            # Parse start and end dates from various formats
            if match = line.match(/DEL\s+(\d{2}-[A-Z]{3}-\d{4})\s+AL\s+(\d{2}-[A-Z]{3}-\d{4})/)
              # Santander format: "DEL 01-AGO-2025 AL 31-AGO-2025"
              period_info["start_date"] = parse_spanish_date(match[1])
              period_info["end_date"] = parse_spanish_date(match[2])
            elsif match = line.match(/DEL\s+(\d{2}\/\d{2}\/\d{4})\s+AL\s+(\d{2}\/\d{2}\/\d{4})/)
              # BBVA format: "DEL 01/07/2025 AL 31/07/2025"
              period_info["start_date"] = parse_ddmmyyyy_date(match[1])
              period_info["end_date"] = parse_ddmmyyyy_date(match[2])
            end
          elsif line.include?("Fecha de Corte")
            period_info["cutoff_date"] = line.split("Fecha de Corte").last&.strip
          end
        end

        period_info
      end
    end
  end
end
