# Convert transactions to array for safe iteration
transactions_array = @transactions.respond_to?(:to_a) ? @transactions.to_a : (@transactions || [])

json.transactions transactions_array do |transaction|
  json.partial! "transactions/transaction", transaction: transaction
end

json.pagination do
  if @pagy && @pagy.respond_to?(:page)
    json.page @pagy.page
    json.items @pagy.vars[:items]  # Access items from vars hash
    json.count @pagy.count
    json.pages @pagy.pages
    json.next @pagy.next
    json.prev @pagy.prev
  else
    json.page 1
    json.items 0
    json.count 0
    json.pages 0
    json.next nil
    json.prev nil
  end
end

json.stats @stats || {}

json.filters do
  if @filters
    json.bank_account_id @filters[:bank_account_id]
    json.statement_file_id @filters[:statement_file_id]
    json.transaction_type @filters[:transaction_type]
    json.from_date @filters[:from_date]
    json.to_date @filters[:to_date]
    json.search @filters[:search]
  end
end

json.sort do
  json.field @current_sort || "date"
  json.direction @current_direction || "desc"
end
