# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/statement_file", statement_file: @statement_file)
end

json.message(@message) if @message.present?
