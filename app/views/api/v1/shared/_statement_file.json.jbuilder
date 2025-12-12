# frozen_string_literal: true

# IMPORTANT: This partial requires eager loading of :bank_account association
# to avoid N+1 queries. Ensure queries include:
# .includes(:bank_account)

json.id(statement_file.id)
json.filename(statement_file.file&.filename&.to_s)
json.status(statement_file.status)
json.processed_at(statement_file.processed_at&.iso8601)
json.created_at(statement_file.created_at.iso8601)
json.bank_account do
  json.id(statement_file.bank_account.id)
  json.name(statement_file.bank_account.display_name)
end
