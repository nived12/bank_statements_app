# frozen_string_literal: true

class AddRecurringSeriesIdToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :transactions, :recurring_series, foreign_key: true, null: true, index: true
  end
end
