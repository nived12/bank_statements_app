# app/services/statements/financial_summary_creator.rb
module Statements
  class FinancialSummaryCreator < ApplicationService
    include ErrorHandling

    def initialize(statement_file, summary_data, statement_type = nil)
      super()
      @statement_file = statement_file
      @summary_data = summary_data.with_indifferent_access
      @statement_type = statement_type || determine_statement_type
    end

    def call
      validated = validate_and_prepare_data
      return failure unless validated

      summary = create_summary(validated)
      return failure unless summary

      Rails.logger.info(
        "Created financial summary for statement #{statement_file.id}: " \
        "type=#{validated[:statement_type]}, period=#{validated[:period_start]}..#{validated[:period_end]}"
      )

      success(summary)
    rescue StandardError => e
      log_error(e, context: "FinancialSummaryCreator", data: context_for_logging)
      errors.add(:base, "Failed to create financial summary: #{e.message}")
      failure
    end

    private

    attr_reader :statement_file, :summary_data, :statement_type

    def validate_and_prepare_data
      {
        statement_type: statement_type,
        initial_balance: extract_decimal("opening_balance"),
        final_balance: extract_decimal("closing_balance"),
        period_start: parse_date("start_date"),
        period_end: parse_date("end_date"),
        days_in_period: calculate_days_in_period,
        total_commissions: extract_decimal("total_commissions"),
        total_fees: extract_decimal("total_fees"),
        statement_type_data: build_statement_type_data
      }
    end

    def create_summary(data)
      StatementFinancialSummary.create!(
        statement_file: statement_file,
        statement_type: data[:statement_type],
        initial_balance: data[:initial_balance],
        final_balance: data[:final_balance],
        statement_period_start: data[:period_start],
        statement_period_end: data[:period_end],
        days_in_period: data[:days_in_period],
        total_commissions: data[:total_commissions],
        total_fees: data[:total_fees],
        statement_type_data: data[:statement_type_data]
      )
    end

    def extract_decimal(key)
      value = summary_data[key]
      return 0.0 if value.blank?

      value.to_f
    end

    def parse_date(key)
      date_string = summary_data[key]
      return if date_string.blank?

      case date_string
      when Date
        date_string
      when /\A\d{4}-\d{2}-\d{2}\z/
        Date.parse(date_string)
      when /\A\d{2}\/\d{2}\/\d{4}\z/
        Date.strptime(date_string, "%d/%m/%Y")
      when /\A\d{2}\/[A-Za-z]{3}\/\d{4}\z/
        Date.strptime(date_string, "%d/%b/%Y")
      else
        Date.parse(date_string)
      end
    rescue Date::Error, ArgumentError => e
      Rails.logger.warn("Failed to parse date '#{date_string}': #{e.message}")
      nil
    end

    def calculate_days_in_period
      return summary_data["period_days"].to_i if summary_data["period_days"].present?

      period_start = parse_date("start_date")
      period_end = parse_date("end_date")

      return 0 if period_start.blank? || period_end.blank?

      (period_end - period_start).to_i + 1
    end

    def build_statement_type_data
      case statement_type
      when "savings", "payroll", "checking"
        build_savings_data
      when "credit"
        build_credit_data
      else
        {}
      end
    end

    def build_savings_data
      {
        "total_deposits" => extract_decimal("total_deposits"),
        "total_withdrawals" => extract_decimal("total_withdrawals"),
        "interest_earned" => extract_decimal("interest_earned"),
        "average_balance" => extract_decimal("average_balance")
      }
    end

    def build_credit_data
      {
        "total_payments" => extract_decimal("total_deposits"),
        "total_charges" => extract_decimal("total_withdrawals"),
        "interest_charged" => -extract_decimal("interest_earned"),
        "credit_limit" => summary_data["credit_limit"],
        "available_credit" => summary_data["available_credit"],
        "payment_to_avoid_interest" => summary_data["payment_to_avoid_interest"],
        "minimum_payment" => summary_data["minimum_payment"]
      }
    end

    def determine_statement_type
      case statement_file.bank_account&.account_type
      when "credit" then "credit"
      when "debit" then "savings"
      when "checking" then "checking"
      else "savings"
      end
    end

    def context_for_logging
      {
        statement_file_id: statement_file.id,
        bank_account: statement_file.bank_account&.bank_name,
        account_type: statement_file.bank_account&.account_type,
        summary_data_keys: summary_data.keys
      }
    end
  end
end
