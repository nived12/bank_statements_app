# frozen_string_literal: true

json.data do
  json.partial!("api/v1/shared/recurring_series", series: @series)
  json.transactions(@transactions || []) do |tx|
    json.partial!("api/v1/shared/transaction", transaction: tx)
  end if @transactions
end
