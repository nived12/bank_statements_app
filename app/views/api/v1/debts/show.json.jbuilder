# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/debt", debt: @debt)
end

json.message(@message) if @message.present?
