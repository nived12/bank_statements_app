# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/statement_file", statement_file: @statement_file)

  # Detail only — the index would pay for a summary per row and never render it.
  if @statement_file.financial_summary.present?
    json.financial_summary do
      json.partial!("api/v1/shared/financial_summary", summary: @statement_file.financial_summary)
    end
  end
end

json.message(@message) if @message.present?
