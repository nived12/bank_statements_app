# frozen_string_literal: true

# IMPORTANT: This partial requires eager loading of associations to avoid N+1 queries
# Ensure queries include: .includes(:bank_account, :category, linked_transfer: :bank_account)

json.id(transaction.id)
json.date(transaction.date.iso8601)
json.description(transaction.description)
json.amount(transaction.amount.to_f)
json.transaction_type(transaction.transaction_type)
json.source(transaction.source)
json.merchant(transaction.merchant)
json.reference(transaction.reference)

# Bank account (always present)
json.bank_account do
  json.id(transaction.bank_account.id)
  json.name(transaction.bank_account.display_name)
  json.account_type(transaction.bank_account.account_type)
end

# Category (optional)
if transaction.category.present?
  json.category do
    json.id(transaction.category.id)
    json.name(transaction.category.name)
    json.icon(transaction.category.icon)
  end
else
  json.category(nil)
end

# Transfer information (if applicable)
if transaction.respond_to?(:transfer?) && transaction.transfer?
  json.is_transfer(true)
  if transaction.linked_transfer.present?
    json.transfer_account do
      json.id(transaction.linked_transfer.bank_account.id)
      json.name(transaction.linked_transfer.bank_account.display_name)
    end
  end
else
  json.is_transfer(false)
end

# Timestamps
json.created_at(transaction.created_at.iso8601)
json.updated_at(transaction.updated_at.iso8601)
