# frozen_string_literal: true

# IMPORTANT: This partial requires eager loading of :bank_account and :category associations
# to avoid N+1 queries. Ensure queries include:
# .includes(:bank_account, :category)

json.id(transaction.id)
json.date(transaction.date.iso8601)
json.description(transaction.description)
json.amount(transaction.amount)
json.transaction_type(transaction.transaction_type)
json.bank_account do
  json.id(transaction.bank_account.id)
  json.name(transaction.bank_account.display_name)
end
json.category do
  json.id(transaction.category.id)
  json.name(transaction.category.name)
  json.icon(transaction.category.icon)
end
