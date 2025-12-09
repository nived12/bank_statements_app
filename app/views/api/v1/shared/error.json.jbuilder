# frozen_string_literal: true

json.error do
  json.message @error_message
  json.code @error_code
  json.details @error_details if @error_details.present?
end
