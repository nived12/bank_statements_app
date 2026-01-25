# frozen_string_literal: true

# IMPORTANT: This partial requires eager loading of :bank_account association
# to avoid N+1 queries. Ensure queries include:
# .includes(:bank_account)

json.extract!(statement_file, :id, :status, :processing_strategy, :processed_at, :created_at, :updated_at)

json.filename(statement_file.file&.filename&.to_s)
json.file_size(statement_file.file&.byte_size)
json.cutoff_date(statement_file.cutoff_date&.iso8601)
json.error_message(statement_file.error_message) if statement_file.error?

json.bank_account do
  json.id(statement_file.bank_account.id)
  json.display_name(statement_file.bank_account.display_name)
  json.account_number(statement_file.bank_account.account_number)
end

json.transactions_count(statement_file.transactions.size)
