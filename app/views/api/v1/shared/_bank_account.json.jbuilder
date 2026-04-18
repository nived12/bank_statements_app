# frozen_string_literal: true

json.extract!(
  bank_account, :id, :account_number, :currency, :opening_balance, :opening_balance_date, :custom_name,
  :account_type, :created_at, :updated_at
)

json.name(bank_account.display_name)
json.display_name(bank_account.display_name)
json.balance(bank_account.effective_balance.to_f)
json.bank_id(bank_account.bank_id)
json.bank_name(bank_account.bank&.name)

if bank_account.bank.present?
  json.bank do
    json.id(bank_account.bank.id)
    json.code(bank_account.bank.code)
    json.name(bank_account.bank.name)
    json.supported_for_parsing(bank_account.bank.supported_for_parsing?)
  end
else
  json.bank(nil)
end

json.transactions_count(bank_account.transactions.size)
