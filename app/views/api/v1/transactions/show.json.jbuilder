# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/transaction", transaction: @transaction)
end

# Optional success message (for create/update operations)
json.message(@message) if @message.present?
