# app/services/financial_summary_service.rb
class FinancialSummaryService < ApplicationService
  include ErrorHandling

  def initialize(statement)
    @statement = statement
    @bank_account = statement.bank_account
  end

  def call
    # This service can be called directly, but the main methods are create_from_extracted_data and create_financial_summary
    success
  end

  def create_from_extracted_data(financial_data)
    # Validate and prepare data
    validated_data = validate_and_prepare_data(financial_data)

    # Create the financial summary
    summary = StatementFinancialSummary.create!(
      statement_file: statement,
      statement_type: validated_data[:statement_type],
      initial_balance: validated_data[:initial_balance],
      final_balance: validated_data[:final_balance],
      statement_period_start: validated_data[:start_date],
      statement_period_end: validated_data[:end_date],
      days_in_period: validated_data[:period_duration],
      total_commissions: validated_data[:total_commissions],
      total_fees: validated_data[:total_fees],
      statement_type_data: validated_data[:statement_type_data]
    )

    summary
  rescue => e
    log_error(e, context: "FinancialSummary", data: { financial_data: financial_data })
    errors.add(:base, :creation_failed, message: e.message)
    nil
  end

  def create_financial_summary(summary_data, summary_type)
    # Extract and validate AI data
    validated_data = validate_ai_data(summary_data, summary_type)

    # Create the financial summary
    summary = StatementFinancialSummary.create!(
      statement_file: statement,
      statement_type: validated_data[:statement_type],
      initial_balance: validated_data[:initial_balance],
      final_balance: validated_data[:final_balance],
      statement_period_start: validated_data[:period_start],
      statement_period_end: validated_data[:period_end],
      days_in_period: validated_data[:days_in_period],
      total_commissions: validated_data[:total_commissions],
      total_fees: validated_data[:total_fees],
      statement_type_data: validated_data[:statement_type_data]
    )

    Rails.logger.info("Created AI financial summary: #{summary_type} - #{validated_data[:description]} - #{validated_data[:amount]}")
    summary
  rescue => e
    log_error(e, context: "FinancialSummary", data: { summary_data: summary_data, summary_type: summary_type })
    errors.add(:base, :creation_failed, message: e.message)
    nil
  end

  private

  attr_reader :statement, :bank_account

  def validate_and_prepare_data(financial_data)
    # Provide defaults for missing required fields
    statement_type = financial_data[:statement_type] || "savings"
    initial_balance = financial_data[:initial_balance] || 0.0
    final_balance = financial_data[:final_balance] || 0.0
    period_dates = financial_data[:period_dates] || {}

    # Calculate period duration with fallback
    period_duration = calculate_period_duration(period_dates) || 30

    # Ensure we have valid period dates
    start_date, end_date = prepare_period_dates(period_dates, period_duration)

    # Prepare commission and fee data
    commission_info = financial_data[:commission_info] || {}
    total_commissions = commission_info.values.first || 0.0
    total_fees = commission_info.values.last || 0.0

    {
      statement_type: statement_type,
      initial_balance: initial_balance,
      final_balance: final_balance,
      start_date: start_date,
      end_date: end_date,
      period_duration: period_duration,
      total_commissions: total_commissions,
      total_fees: total_fees,
      statement_type_data: financial_data[:statement_type_data] || {}
    }
  end

  def prepare_period_dates(period_dates, period_duration)
    if period_dates.empty?
      # Use fallback dates
      start_date = statement.created_at.to_date - 30.days
      end_date = statement.created_at.to_date
    else
      start_date = period_dates["start"] || period_dates.values.first
      end_date = period_dates["end"] || period_dates.values.last

      # Validate dates and use fallback if invalid
      if start_date && end_date && end_date < start_date
        Rails.logger.warn("Invalid period dates: start=#{start_date}, end=#{end_date}. Using fallback dates.")
        start_date = statement.created_at.to_date - 30.days
        end_date = statement.created_at.to_date
      end
    end

    [ start_date, end_date ]
  end

  def validate_ai_data(summary_data, summary_type)
    amount = summary_data["amount"] || 0.0
    description = summary_data["description"] || ""
    date = summary_data["date"] || statement.created_at.to_date
    details = summary_data["details"] || {}
    raw_text = summary_data["raw_text"] || ""

    # Determine statement type and prepare period data
    statement_type = determine_statement_type
    period_start = date
    period_end = date + 1.day

    # Prepare balance and fee data based on summary type
    initial_balance = summary_type == "opening_balance" ? amount : 0.0
    final_balance = summary_type == "closing_balance" ? amount : 0.0
    total_commissions = summary_type == "commission" ? amount : 0.0
    total_fees = summary_type == "fee" ? amount : 0.0

    {
      statement_type: statement_type,
      initial_balance: initial_balance,
      final_balance: final_balance,
      period_start: period_start,
      period_end: period_end,
      days_in_period: 2,
      total_commissions: total_commissions,
      total_fees: total_fees,
      description: description,
      amount: amount,
      statement_type_data: {
        "ai_extracted_type" => summary_type,
        "ai_description" => description,
        "ai_details" => details,
        "ai_raw_text" => raw_text,
        "ai_amount" => amount
      }
    }
  end

  def calculate_period_duration(period_dates)
    return nil if period_dates.empty?

    start_date = period_dates["start"] || period_dates.values.first
    end_date = period_dates["end"] || period_dates.values.last

    return nil unless start_date && end_date

    (end_date - start_date).to_i + 1
  rescue => e
    Rails.logger.error("Error calculating period duration: #{e.message}")
    nil
  end

  def determine_statement_type
    case bank_account.account_type
    when "credit"
      "credit"
    when "debit"
      "savings"
    when "checking"
      "checking"
    else
      "savings"  # Default fallback
    end
  end

  def context_for_logging
    {
      statement_id: statement.id,
      bank_account: bank_account&.bank_name,
      account_type: bank_account&.account_type
    }
  end
end
