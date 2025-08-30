# frozen_string_literal: true

##
# ErrorHandling
# Concern module for error handling that can be included in services
#
# Usage:
# include ErrorHandling in your service class and you can use:
#   handle_statement_error(statement, error)
#   handle_pii_error(statement, error)
#   handle_financial_summary_error(error, financial_data)
#
module ErrorHandling
  private

  def handle_statement_error(statement, error)
    statement.update(
      status: "error",
      processed_at: Time.current,
      error_message: "Statement processing failed: #{error.message}"
    )
    Rails.logger.error("StatementIngestJob failed for statement #{statement.id}: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))
  end

  def handle_pii_error(statement, error)
    statement.update(
      status: "error",
      processed_at: Time.current,
      error_message: "PII redaction failed: #{error.message}"
    )
    Rails.logger.error("[PII] Redaction failed: #{error.message}")
  end

  def handle_financial_summary_error(error, financial_data = nil)
    Rails.logger.error("Failed to create financial summary: #{error.message}")
    Rails.logger.error("Financial data: #{financial_data.inspect}") if financial_data
  end

  def handle_ai_financial_summary_error(error)
    Rails.logger.error("Failed to create AI financial summary: #{error.message}")
  end
end
