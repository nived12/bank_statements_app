# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/goal", goal: @goal)
end

json.message(@message) if @message.present?
