# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/saving", saving: @saving, detailed: true)
end

json.message(@message) if @message.present?
