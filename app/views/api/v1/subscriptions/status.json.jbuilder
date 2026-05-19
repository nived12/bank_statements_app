# frozen_string_literal: true

json.data do
  json.plan @plan
  json.status @status
  json.billing_interval @billing_interval
  json.trial_ends_at @trial_ends_at&.iso8601
  json.current_period_end @current_period_end&.iso8601
  json.cancel_at_period_end @cancel_at_period_end
  json.ai_calls_used @ai_calls_used
  json.ai_calls_limit @ai_calls_limit
  json.statement_files_used @statement_files_used
  json.statement_files_limit @statement_files_limit
end
