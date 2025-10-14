json.array! @bank_accounts do |bank_account|
  json.id bank_account.id
  json.bank_display_name bank_account.bank_display_name
  json.account_number bank_account.account_number
  json.custom_name bank_account.custom_name
end
