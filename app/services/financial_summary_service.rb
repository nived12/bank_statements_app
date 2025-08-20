# app/services/financial_summary_service.rb
class FinancialSummaryService
  def initialize(statement)
    @statement = statement
    @bank_account = statement.bank_account
  end

  def create_from_extracted_data(financial_data)
    # Provide defaults for missing required fields
    statement_type = financial_data[:statement_type] || "savings"
    initial_balance = financial_data[:initial_balance] || 0.0
    final_balance = financial_data[:final_balance] || 0.0
    period_dates = financial_data[:period_dates] || {}

    # Calculate period duration with fallback
    period_duration = calculate_period_duration(period_dates)
    if period_duration.nil?
      # Fallback: use statement creation date as period
      period_duration = 30 # Default to 30 days
    end

    # Ensure we have at least some period dates
    if period_dates.empty?
      period_dates = {
        "start" => statement.created_at.to_date - 30.days,
        "end" => statement.created_at.to_date
      }
    end

    # Validate that end date is not before start date (same-day periods are valid)
    start_date = period_dates["start"] || period_dates.values.first
    end_date = period_dates["end"] || period_dates.values.last

    if start_date && end_date && end_date < start_date
      Rails.logger.warn("Invalid period dates: start=#{start_date}, end=#{end_date}. Using fallback dates.")
      # Use fallback dates that are guaranteed to be valid
      start_date = statement.created_at.to_date - 30.days
      end_date = statement.created_at.to_date
      period_duration = 30
    end

    # Create the financial summary with validated dates
    summary = StatementFinancialSummary.create!(
      statement_file: statement,
      statement_type: statement_type,
      initial_balance: initial_balance,
      final_balance: final_balance,
      statement_period_start: start_date,
      statement_period_end: end_date,
      days_in_period: period_duration,
      total_commissions: financial_data[:commission_info]&.values&.first || 0.0,
      total_fees: financial_data[:commission_info]&.values&.last || 0.0,
      statement_type_data: financial_data[:statement_type_data] || {}
    )

    summary
  rescue => e
    ErrorHandlingService.handle_financial_summary_error(e, financial_data)
    # Don't fail the entire job if financial summary creation fails
    nil
  end

  def create_from_ai_data(summary_data, summary_type)
    # Extract data from AI summary
    amount = summary_data["amount"] || 0.0
    description = summary_data["description"] || ""
    date = summary_data["date"] || statement.created_at.to_date
    details = summary_data["details"] || {}
    raw_text = summary_data["raw_text"] || ""

    # Determine statement type based on bank account
    statement_type = determine_statement_type

    # Create the financial summary
    # For single-date entries, use a 1-day period
    period_start = date
    period_end = date + 1.day

    summary = StatementFinancialSummary.create!(
      statement_file: statement,
      statement_type: statement_type,
      initial_balance: summary_type == "opening_balance" ? amount : 0.0,
      final_balance: summary_type == "closing_balance" ? amount : 0.0,
      statement_period_start: period_start,
      statement_period_end: period_end,
      days_in_period: 2,
      total_commissions: summary_type == "fee" ? amount : 0.0,
      total_fees: summary_type == "commission" ? amount : 0.0,
      statement_type_data: {
        "ai_extracted_type" => summary_type,
        "ai_description" => description,
        "ai_details" => details,
        "ai_raw_text" => raw_text,
        "ai_amount" => amount
      }
    )

    Rails.logger.info("Created AI financial summary: #{summary_type} - #{description} - #{amount}")
    summary
  rescue => e
    ErrorHandlingService.handle_ai_financial_summary_error(e)
    # Don't fail the entire job if financial summary creation fails
    nil
  end

  def create_from_parsed_data(parsed_data)
    return unless parsed_data["financial_summaries"]&.any?

    created_count = 0
    parsed_data["financial_summaries"].each do |summary_data|
      # Create StatementFinancialSummary records based on the type
      case summary_data["type"]
      when "balance"
        # Create financial summary for balance information
        if summary_data["description"]&.downcase&.include?("opening") || summary_data["description"]&.downcase&.include?("inicial")
          # This is an opening balance
          create_from_ai_data(summary_data, "opening_balance")
        elsif summary_data["description"]&.downcase&.include?("closing") || summary_data["description"]&.downcase&.include?("final")
          # This is a closing balance
          create_from_ai_data(summary_data, "closing_balance")
        else
          # Generic balance entry
          create_from_ai_data(summary_data, "balance")
        end
      when "fee", "commission"
        # Create financial summary for fees/commissions
        create_from_ai_data(summary_data, "fee")
      when "installment"
        # Create financial summary for installment information
        create_from_ai_data(summary_data, "installment")
      else
        # Handle any other types
        create_from_ai_data(summary_data, "other")
      end
      created_count += 1
    end

    Rails.logger.info("Created #{created_count} financial summaries from parsed data")
    created_count
  end

  private

  attr_reader :statement, :bank_account

  def calculate_period_duration(period_dates)
    return nil unless period_dates&.any?

    start_date = period_dates.values.first
    end_date = period_dates.values.last
    return nil unless start_date && end_date

    (end_date - start_date).to_i + 1
  end

  def determine_statement_type
    # Determine statement type based on parser type or default to savings
    case bank_account.parser_type&.downcase
    when "credit", "credit_card"
      "credit"
    when "savings", "checking", "debit"
      "savings"
    else
      # Default to savings for unknown types
      "savings"
    end
  end
end
