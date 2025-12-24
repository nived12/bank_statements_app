# frozen_string_literal: true

json.data do
  json.bank_accounts(@bank_accounts) do |bank_account|
    json.partial!("api/v1/shared/bank_account", bank_account: bank_account)
  end
end
