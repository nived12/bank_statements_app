# frozen_string_literal: true

json.error do
  json.message(@error_message)
  json.code(@error_code)
  json.details(@error_details || [])
  json.reason(@error_reason) if @error_reason.present?
end
