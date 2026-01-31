# app/services/pdf_parser/base.rb
require "bigdecimal"
require "date"

module PdfParser
  class Base < ApplicationService
    # Spanish month abbreviations used across Mexican bank statements
    SPANISH_MONTHS = {
      "ENE" => "01", "FEB" => "02", "MAR" => "03", "ABR" => "04",
      "MAY" => "05", "JUN" => "06", "JUL" => "07", "AGO" => "08",
      "SEP" => "09", "OCT" => "10", "NOV" => "11", "DIC" => "12"
    }.freeze

    def initialize(text)
      super()
      @text = text
    end

    def call
      result = parse(@text)
      if result && result.is_a?(Hash)
        success(result)
      else
        errors.add(:base, :parsing_failed, message: "Failed to parse PDF content")
        failure
      end
    rescue => e
      errors.add(:base, :parsing_error, message: e.message)
      failure
    end

    private

    def parse(_text)
      raise NotImplementedError
    end

    protected

    # ========== Text Processing ==========

    def split_lines(text)
      text.to_s.split(/\r?\n/).map(&:strip).compact_blank
    end

    def should_skip_line?(line, patterns)
      patterns.any? { |pattern| line.match?(pattern) }
    end

    # ========== Section Extraction ==========

    def extract_section(lines, start_pattern, end_pattern)
      section_lines = []
      in_section = false

      lines.each do |line|
        if line.match?(start_pattern)
          in_section = true
          next
        end

        break if in_section && line.match?(end_pattern)

        section_lines << line if in_section
      end

      section_lines
    end

    # ========== Date Parsing ==========

    def spanish_month_to_number(month)
      SPANISH_MONTHS[month.upcase]
    end

    # Normalize date from day, Spanish month, and year (2 or 4 digit)
    def normalize_spanish_date(day, month, year)
      month_num = spanish_month_to_number(month)
      return unless month_num

      full_year = year.length == 2 ? (year.to_i < 50 ? "20#{year}" : "19#{year}") : year
      sprintf("%s-%s-%02d", full_year, month_num, day.to_i)
    end

    def normalize_ddmm_date(day, month, year)
      sprintf("%04d-%02d-%02d", year.to_i, month.to_i, day.to_i)
    end

    def normalize_date_ddmmyyyy(str)
      if str =~ /\A(\d{2})[\/\-](\d{2})[\/\-](\d{4})\z/
        "#{Regexp.last_match(3)}-#{Regexp.last_match(2)}-#{Regexp.last_match(1)}"
      else
        str
      end
    rescue
      str
    end

    # ========== Amount Parsing ==========

    def parse_decimal(str)
      s = str.to_s.strip
      return if s.empty?

      negative = false
      if s.start_with?("(") && s.end_with?(")")
        negative = true
        s = s[1..-2]
      end
      s = s.delete(" ")

      normalized =
        if s.count(",") >= 1 && s.count(".") >= 1
          s.tr(",", "")
        elsif s.count(",") >= 1 && s.count(".") == 0
          s.tr(",", ".")
        else
          s
        end

      bd = BigDecimal(normalized)
      negative ? -bd : bd
    rescue
      nil
    end

    # Parse signed amount (+/-) with standard convention (+ = income, - = expense)
    def parse_signed_amount(sign, amount_str)
      value = amount_str.gsub(",", "").to_f
      sign == "+" ? [value, "income"] : [-value, "variable_expense"]
    end

    # Parse signed amount with inverted convention (+ = expense, - = income)
    # Used by some credit cards like Scotiabank
    def parse_inverted_signed_amount(sign, amount_str)
      value = amount_str.gsub(",", "").to_f
      sign == "+" ? [-value, "variable_expense"] : [value, "income"]
    end

    def extract_amount_from_text(text)
      match = text.match(/\+?\s*\$?\s*([\d,]+\.\d{2})/)
      match[1].gsub(",", "").to_f if match
    end

    # ========== Result Building ==========

    def build_result(transactions:, opening_balance: nil, closing_balance: nil, summary: nil)
      {
        "extraction_source" => "deterministic_parser",
        "transactions" => transactions,
        "opening_balance" => opening_balance,
        "closing_balance" => closing_balance,
        "financial_summaries" => summary ? [summary] : []
      }
    end

    def build_transaction(date:, description:, amount:, transaction_type:, merchant: nil, reference: nil, raw_text: nil)
      {
        "date" => date,
        "description" => description,
        "amount" => sprintf("%.2f", amount),
        "transaction_type" => transaction_type,
        "merchant" => merchant,
        "reference" => reference,
        "raw_text" => raw_text
      }
    end

    def build_credit_summary(bank_name:, opening_balance: nil, closing_balance: nil, **extras)
      build_summary("credit", bank_name, opening_balance, closing_balance, extras)
    end

    def build_debit_summary(bank_name:, opening_balance: nil, closing_balance: nil, **extras)
      build_summary("debit", bank_name, opening_balance, closing_balance, extras)
    end

    def build_summary(type, bank_name, opening_balance, closing_balance, extras)
      summary = {
        "statement_type" => type,
        "bank_name" => bank_name,
        "opening_balance" => opening_balance,
        "closing_balance" => closing_balance
      }
      extras.each { |k, v| summary[k.to_s] = v if v }
      summary
    end
  end
end
