# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/bank_account", bank_account: @bank_account)
end

json.message(@message) if @message.present?
